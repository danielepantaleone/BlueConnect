//
//  BlePeripheralProxy+CharacteristicRead.swift
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
    
    /// Reads the value of a characteristic and notifies the result through the provided callback.
    ///
    /// This method attempts to read the characteristic's value, either from the peripheral or the cache, depending on the specified cache policy.
    /// If a read operation for the same characteristic is already in progress, the operation will not be triggered again.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic to read.
    ///   - cachePolicy: The cache policy that dictates whether the value should be fetched from the peripheral or retrieved from the cache. Defaults to `.never`, meaning fresh data is read directly from the peripheral unless specified otherwise.
    ///   - timeout: The timeout for the characteristic read operation. This is ignored if the value is fetched from the cache. Defaults to 10 seconds.
    ///   - callback: A closure that is executed when the read operation completes. The closure is passed a `Result` containing the characteristic's data or an error if the read fails.
    ///
    /// - Note: The read operation will only occur if no other read for the same characteristic is already in progress. Multiple simultaneous read requests for the same characteristic will not trigger multiple read operations.
    public func read(
        characteristicUUID: CBUUID,
        cachePolicy: BlePeripheralCachePolicy = .never,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Data, Error>) -> Void
    ) {
        let subscription = buildSubscription(characteristicUUID: characteristicUUID, timeout: timeout, callback: callback)
        read(characteristicUUID: characteristicUUID, cachePolicy: cachePolicy, subscription: subscription)
    }
    
    /// Reads the value of a characteristic.
    ///
    /// This method attempts to read the characteristic's value, either from the peripheral or the cache, depending on the specified cache policy.
    /// If a read operation for the same characteristic is already in progress, the operation will not be triggered again.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic to read.
    ///   - cachePolicy: The cache policy dictating whether to fetch the value from the peripheral or use cached data. Defaults to `.never`, meaning fresh data is read directly from the peripheral.
    ///   - timeout: The timeout duration for the read operation. Ignored if fetching from cache. Defaults to 10 seconds.
    ///
    /// - Returns: The characteristic data as `Data`.
    /// - Throws: An error if the characteristic cannot be read within the specified timeout or contains no data.
    public func read(
        characteristicUUID: CBUUID,
        cachePolicy: BlePeripheralCachePolicy,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> Data {
        let box = SubscriptionBox<Data>()
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
                    characteristicReadRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
                } else {
                    read(characteristicUUID: characteristicUUID, cachePolicy: cachePolicy, subscription: subscription)
                }
            }
        } onCancel: {
            box.lock()
            box.isCancelled = true
            let subscription = box.subscription
            box.unlock()
            guard let subscription else { return }
            characteristicReadRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
        }
    }
    
    // MARK: - Private
        
    private func buildSubscription(
        characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval,
        callback: @escaping (Result<Data, Error>) -> Void
    ) -> Subscription<Data> {
        characteristicReadRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BlePeripheralProxyError.readTimeout(characteristicUUID: characteristicUUID)))
            }
        )
    }
    
    private func read(
        characteristicUUID: CBUUID,
        cachePolicy: BlePeripheralCachePolicy,
        subscription: Subscription<Data>
    ) {
        
        var resultToNotify: Result<Data, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                characteristicReadRegistry.notify(subscription: subscription, value: result)
            }
        }
    
        if let record = cache[characteristicUUID], cachePolicy.isValid(time: record.time) {
            resultToNotify = .success(record.data)
            return
        }
        
        guard peripheral.state == .connected else {
            resultToNotify = .failure(BlePeripheralProxyError.peripheralNotConnected)
            return
        }
        
        guard let characteristic = getCharacteristic(characteristicUUID) else {
            resultToNotify = .failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID))
            return
        }
        
        guard characteristic.properties.contains(.read) else {
            resultToNotify = .failure(BlePeripheralProxyError.readNotSupported(characteristicUUID: characteristicUUID))
            return
        }
        
        // Begin monitoring characteristic read timeout.
        subscription.start()
        
        // Characteristic is already being read from the peripheral so avoid sending multiple read requests
        guard !readingCharacteristics.contains(characteristicUUID) else {
            return
        }
        
        // Read from the peripheral.
        readingCharacteristics.insert(characteristicUUID)
        peripheral.readValue(for: characteristic)
        
    }
    
}
