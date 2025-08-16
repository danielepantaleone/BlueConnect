//
//  BlePeripheralProxy+CharacteristicDiscovery.swift
//  BlueConnect
//
//  GitHub Repo and Documentation: https://github.com/danielepantaleone/BlueConnect
//
//  Copyright © 2025 Daniele Pantaleone. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

extension BlePeripheralProxy {
    
    // MARK: - Public
    
    /// Discover a specific characteristic for the provided service and register a callback to be executed when the characteristic is discovered.
    ///
    /// The discovered characteristic will also be notified via the `didDiscoverCharacteristicsPublisher`.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic to discover.
    ///   - serviceUUID: The UUID of the service containing the characteristic.
    ///   - timeout: The timeout duration for the characteristic discovery operation. Defaults to 10 seconds.
    ///   - callback: A closure to execute when the characteristic is discovered. The closure provides a `Result` containing either the discovered `CBCharacteristic` or an `Error`.
    public func discover(
        characteristicUUID: CBUUID,
        in serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<CBCharacteristic, Error>) -> Void
    ) {
        let subscription = buildSubscription(characteristicUUID: characteristicUUID, timeout: timeout, callback: callback)
        discover(characteristicUUID: characteristicUUID, in: serviceUUID, subscription: subscription)
    }
    
    /// Discover a set of characteristics for the provided service, or all available characteristics if `nil` is specified for `characteristicUUIDs`.
    ///
    /// The discovered characteristics will trigger notifications via the `didDiscoverCharacteristicsPublisher`, which can be triggered multiple times.
    /// If specific characteristics are not found, they will not be advertised, so using `discover(characteristicUUID:in:timeout:callback)` is recommended for specific use cases.
    ///
    /// - Parameters:
    ///   - characteristicUUIDs: An array of UUIDs representing the characteristics to discover, or `nil` to discover all characteristics for the service.
    ///   - serviceUUID: The UUID of the service containing the characteristics.
    public func discover(characteristicUUIDs: [CBUUID]?, in serviceUUID: CBUUID) {
  
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            return
        }

        guard let service = getService(serviceUUID) else {
            return
        }
        
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        
    }
    
    /// Discover a specific characteristic for the provided service and returns the discovered characteristic.
    ///
    /// This method also triggers the `didDiscoverCharacteristicsPublisher`.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic to discover.
    ///   - serviceUUID: The UUID of the service containing the characteristic.
    ///   - timeout: The timeout duration for the characteristic discovery operation. Defaults to 10 seconds.
    ///
    /// - Returns: The discovered `CBCharacteristic`.
    /// - Throws: An error if the characteristic cannot be discovered within the specified timeout.
    @discardableResult
    public func discover(
        characteristicUUID: CBUUID,
        in serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> CBCharacteristic {
        let box = SubscriptionBox<CBCharacteristic>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildSubscription(
                    characteristicUUID: characteristicUUID,
                    timeout: timeout
                ) { result in
                    globalQueue.async {
                        continuation.resume(with: result)
                    }
                }
                box.lock()
                box.subscription = subscription
                let wasCancelled = box.isCancelled
                box.unlock()
                if wasCancelled {
                    discoverCharacteristicRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
                } else {
                    discover(characteristicUUID: characteristicUUID, in: serviceUUID, subscription: subscription)
                }
            }
        } onCancel: {
            box.lock()
            box.isCancelled = true
            let subscription = box.subscription
            box.unlock()
            guard let subscription else { return }
            discoverCharacteristicRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
        }
    }
    
    // MARK: - Internals
    
    func getCharacteristic(_ uuid: CBUUID) -> CBCharacteristic? {
        lock.lock()
        defer { lock.unlock() }
        for service in peripheral.services.emptyIfNil {
            guard let characteristic = service.characteristics?.first(where: { $0.uuid == uuid }) else {
                continue
            }
            return characteristic
        }
        return nil
    }
    
    func getCharacteristic(_ uuid: CBUUID, serviceUUID: CBUUID) -> CBCharacteristic? {
        lock.lock()
        defer { lock.unlock() }
        guard let service = getService(serviceUUID) else {
            return nil
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == uuid }) else {
            return nil
        }
        return characteristic
    }
    
    // MARK: - Private
    
    private func buildSubscription(
        characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval,
        callback: @escaping (Result<CBCharacteristic, Error>) -> Void
    ) -> Subscription<CBCharacteristic> {
        discoverCharacteristicRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout,
            timeoutHandler: { [weak self] subscription in
                self?.discoverCharacteristicRegistry.notify(subscription: subscription, value: .failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
            }
        )
    }
    
    private func discover(
        characteristicUUID: CBUUID,
        in serviceUUID: CBUUID,
        subscription: Subscription<CBCharacteristic>
    ) {
        
        var resultToNotify: Result<CBCharacteristic, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                discoverCharacteristicRegistry.notify(subscription: subscription, value: result)
            }
        }
            
        guard peripheral.state == .connected else {
            resultToNotify = .failure(BlePeripheralProxyError.peripheralNotConnected)
            return
        }
        
        guard let service = getService(serviceUUID) else {
            resultToNotify = .failure(BlePeripheralProxyError.serviceNotFound(serviceUUID: serviceUUID))
            return
        }
        
        if let characteristic = getCharacteristic(characteristicUUID, serviceUUID: serviceUUID) {
            resultToNotify = .success(characteristic)
            return
        }
            
        // Begin monitoring characteristic discovery timeout.
        subscription.start()

        // Initiate characteristic discovery.
        peripheral.discoverCharacteristics([characteristicUUID], for: service)
        
    }
    
}
