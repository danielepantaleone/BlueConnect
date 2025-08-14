//
//  BlePeripheralProxy+CharacteristicNotify.swift
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
    
    /// Checks whether notification is enabled for a specific characteristic.
    ///
    /// This method verifies if the `isNotifying` flag is set for a characteristic on a connected peripheral.
    /// If the peripheral is not connected, the characteristic is not found, or the characteristic does not support notifications, the method will return a corresponding error via the callback.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic for which to check the notification state.
    ///   - timeout: The timeout duration for the notification check operation. If the operation does not complete within this time, it will fail.
    ///   - callback: A closure to execute when the characteristic notification state is retrieved. The closure receives a `Result` indicating success or failure, with the current notification state as a success value.
    public func isNotifying(
        characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Bool, Error>) -> Void
    ) {
        
        var localCallback: (() -> Void)? = nil

        lock.lock()
        defer {
            lock.unlock()
            localCallback?()
        }

        guard peripheral.state == .connected else {
            localCallback = {
                callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            }
            return
        }

        guard let characteristic = getCharacteristic(characteristicUUID) else {
            localCallback = {
                callback(.failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
            }
            return
        }

        guard characteristic.properties.contains(.notify) else {
            localCallback = {
                callback(.failure(BlePeripheralProxyError.notifyNotSupported(characteristicUUID: characteristicUUID)))
            }
            return
        }

        localCallback = {
            callback(.success(characteristic.isNotifying))
        }
        
    } // TODO: MAKE SYNCHRONOUS
    
    /// Asynchronously checks whether notifications are currently enabled for a specified Bluetooth characteristic.
    ///
    /// This method  checks the `isNotifying` flag of a characteristic on a connected peripheral. If the peripheral is not connected,
    /// the characteristic is not found, or it does not support notifications, the method will throw an appropriate error.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic to check for notification state.
    ///   - timeout: The maximum duration to wait for the notification state check. Defaults to 10 seconds. *(Note: currently unused in implementation)*.
    ///
    /// - Returns: `true` if notifications are enabled for the characteristic; `false` otherwise.
    /// - Throws: An error if the peripheral is not connected, the characteristic is not found, or notification is not supported.
    public func isNotifying(
        characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            isNotifying(characteristicUUID: characteristicUUID, timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
    } // TODO: MAKE SYNCHRONOUS
     
    /// Enables or disables notifications for a specific characteristic.
    ///
    /// This method updates the notification state for the given characteristic and executes the provided callback when the operation is complete.
    /// If notifications are already in the desired state, the callback is called immediately with the current state.
    ///
    /// - Parameters:
    ///   - enabled: `true` to enable notifications, `false` to disable notifications for the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic for which to set the notification state.
    ///   - timeout: The timeout duration for the notification set operation. If the operation does not complete within this time, it will fail.
    ///   - callback: A closure to execute when the characteristic notification state is updated. The closure receives a `Result` indicating success or failure, with the current notification state as a success value.
    ///
    /// - Note: If the desired notification state is already set, the method will immediately return the current state without performing any further operations.
    public func setNotify(
        enabled: Bool,
        for characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Bool, Error>) -> Void
    ) {
        let subscription = buildSubscription(characteristicUUID: characteristicUUID, timeout: timeout, callback: callback)
        setNotify(enabled: enabled, for: characteristicUUID, subscription: subscription)
    
    }
    
    /// Enables or disables notifications for a specific characteristic.
    ///
    /// This method updates the notification state for the given characteristic.
    /// If notifications are already in the desired state this method does nothing.
    ///
    /// - Parameters:
    ///   - enabled: `true` to enable notifications, `false` to disable notifications for the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic for which to set the notification state.
    ///   - timeout: The timeout duration for the notification set operation. If the operation does not complete within this time, it will fail.
    ///
    /// - Note: If the desired notification state is already set, the method will immediately return the current state without performing any further operations.
    /// - Returns: A boolean indicating if notification is enabled (`true`) on the characteristic, or `false` if notification is disabled.
    /// - Throws: An error if the characteristic notify flag cannot be changed within the specified timeout.
    public func setNotify(
        enabled: Bool,
        for characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> Bool {
        let box = SubscriptionBox<Bool>()
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
                    characteristicNotifyRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
                } else {
                    setNotify(enabled: enabled, for: characteristicUUID, subscription: subscription)
                }
            }
        } onCancel: {
            box.lock()
            box.isCancelled = true
            let subscription = box.subscription
            box.unlock()
            guard let subscription else { return }
            characteristicNotifyRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
        }
    }
    
    // MARK: - Private
    
    private func buildSubscription(
        characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval,
        callback: @escaping (Result<Bool, Error>) -> Void
    ) -> Subscription<Bool> {
        characteristicNotifyRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BlePeripheralProxyError.notifyTimeout(characteristicUUID: characteristicUUID)))
            }
        )
    }
    
    private func setNotify(
        enabled: Bool,
        for characteristicUUID: CBUUID,
        subscription: Subscription<Bool>
    ) {
        
        var resultToNotify: Result<Bool, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                characteristicNotifyRegistry.notify(subscription: subscription, value: result)
            }
        }

        guard peripheral.state == .connected else {
            resultToNotify = .failure(BlePeripheralProxyError.peripheralNotConnected)
            return
        }

        guard let characteristic = getCharacteristic(characteristicUUID) else {
            resultToNotify = .failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID))
            return
        }

        guard characteristic.properties.contains(.notify) else {
            resultToNotify = .failure(BlePeripheralProxyError.notifyNotSupported(characteristicUUID: characteristicUUID))
            return
        }

        guard enabled != characteristic.isNotifying else {
            resultToNotify = .success(characteristic.isNotifying)
            return
        }

        // Begin monitoring characteristic notify timeout.
        subscription.start()

        // Set notify value.
        peripheral.setNotifyValue(enabled, for: characteristic)
    
    }
    
}
