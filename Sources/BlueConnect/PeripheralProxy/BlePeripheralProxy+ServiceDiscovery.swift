//
//  BlePeripheralProxy+ServiceDiscovery.swift
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
    
    /// Initiates the discovery of a specific service by its UUID and registers a callback to be executed when the service is discovered.
    ///
    /// The discovered service will also trigger the `didDiscoverServicesPublisher`.
    ///
    /// - Parameters:
    ///   - serviceUUID: The UUID of the service to discover.
    ///   - timeout: The timeout for the service discovery operation. Defaults to 10 seconds.
    ///   - callback: A closure to execute when the service is discovered. The closure provides a `Result` containing either the discovered `CBService` or an `Error`.
    public func discover(
        serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<CBService, Error>) -> Void
    ) {
        let subscription = buildSubscription(serviceUUID: serviceUUID, timeout: timeout, callback: callback)
        discover(serviceUUID: serviceUUID, subscription: subscription)
    }
    
    /// Initiates the discovery of a set of services, or discovers all available services if `nil` is specified as `serviceUUIDs`.
    ///
    /// The discovered services will trigger the `didDiscoverServicesPublisher` multiple times as services are discovered.
    ///
    /// - Parameter serviceUUIDs: The UUIDs of the services to discover, or `nil` to discover all services on the peripheral.
    public func discover(serviceUUIDs: [CBUUID]?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            return
        }
        
        peripheral.discoverServices(serviceUUIDs)
        
    }
    
    /// Initiates the discovery of a specific service by its UUID and returns the discovered service.
    ///
    /// This method also triggers the `didDiscoverServicesPublisher`.
    ///
    /// - Parameters:
    ///   - serviceUUID: The UUID of the service to discover.
    ///   - timeout: The timeout duration for the service discovery operation. Defaults to 10 seconds.
    ///
    /// - Returns: The discovered `CBService`.
    /// - Throws: An error if the service cannot be discovered within the specified timeout.
    @discardableResult
    public func discover(
        serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> CBService {
        let box = SubscriptionBox<CBService>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildSubscription(serviceUUID: serviceUUID, timeout: timeout) { result in
                    globalQueue.async {
                        continuation.resume(with: result)
                    }
                }
                box.value = subscription
                return discover(serviceUUID: serviceUUID, subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                discoverServiceRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    // MARK: - Internal
    
    func getService(_ uuid: CBUUID) -> CBService? {
        lock.lock()
        defer { lock.unlock() }
        return peripheral.services?.first(where: { $0.uuid == uuid })
    }
    
    // MARK: - Private
    
    private func buildSubscription(
        serviceUUID: CBUUID,
        timeout: DispatchTimeInterval,
        callback: @escaping (Result<CBService, Error>) -> Void
    ) -> Subscription<CBService> {
        discoverServiceRegistry.register(
            key: serviceUUID,
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BlePeripheralProxyError.serviceNotFound(serviceUUID: serviceUUID)))
            }
        )
    }
    
    private func discover(serviceUUID: CBUUID, subscription: Subscription<CBService>) {
        
        var resultToNotify: Result<CBService, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                discoverServiceRegistry.notify(subscription: subscription, value: result)
            }
        }
        
        guard peripheral.state == .connected else {
            resultToNotify = .failure(BlePeripheralProxyError.peripheralNotConnected)
            return
        }
        
        if let service = getService(serviceUUID) {
            resultToNotify = .success(service)
            return
        }
        
        // Begin monitoring service discovery timeout.
        subscription.start()

        // Initiate service discovery.
        peripheral.discoverServices([serviceUUID])
        
    }
    
}
