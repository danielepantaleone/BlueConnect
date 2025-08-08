//
//  BlePeripheralProxy+CharacteristicWrite.swift
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
    
    /// Returns the maximum amount of data, in bytes, that can be sent to a characteristic in a single write operation of a given type.
    ///
    /// - Parameter type: The type of write operation, specified by `CBCharacteristicWriteType`.
    /// - Returns: The maximum length, in bytes, that can be sent in a single write operation.
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        return peripheral.maximumWriteValueLength(for: type)
    }
    
    /// Writes a value to a specific characteristic and notifies the result through the provided callback.
    ///
    /// This method writes the specified data to the given characteristic and invokes the callback upon completion.
    /// If the write operation succeeds, the callback is passed a `Result` containing `.success`.
    /// In case of failure, the callback will contain an `Error`.
    ///
    /// - Parameters:
    ///   - data: The data to write to the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic to which the data should be written.
    ///   - timeout: The timeout for the characteristic write operation. Defaults to 10 seconds.
    ///   - callback: A closure that is executed when the write operation completes. The closure is passed a `Result` indicating whether the operation succeeded (`.success`) or failed with an `Error`.
    ///
    /// - Note: The write operation will attempt to complete within the specified timeout, after which it may fail if the peripheral does not respond in time.
    public func write(
        data: Data,
        to characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Void, Error>) -> Void
    ) {
        let subscription = buildSubscription(characteristicUUID: characteristicUUID, timeout: timeout, callback: callback)
        write(data: data, to: characteristicUUID, subscription: subscription)
    }
    
    /// Writes a value to a specific characteristic.
    ///
    /// The method attempts to write the provided data to the specified characteristic and will throw an error if the operation does not succeed.
    ///
    /// - Parameters:
    ///   - data: The data to write to the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic to write the data to.
    ///   - timeout: The timeout duration for the write operation. Defaults to 10 seconds.
    ///
    /// - Throws: An error if the characteristic cannot be written within the specified timeout.
    public func write(
        data: Data,
        to characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws {
        let box = SubscriptionBox<Void>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildSubscription(characteristicUUID: characteristicUUID, timeout: timeout) { result in
                    globalQueue.async {
                        continuation.resume(with: result)
                    }
                }
                box.value = subscription
                write(data: data, to: characteristicUUID, subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                characteristicWriteRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    /// Writes a value to a specific characteristic without triggering a response from the peripheral.
    ///
    /// This method writes the specified data to the given characteristic and does not wait for a response from the peripheral.
    /// If the write operation fails, an error is thrown.
    ///
    /// - Parameters:
    ///   - data: The data to write to the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic to which the data should be written.
    ///
    /// - Throws: `BlePeripheralProxyError.peripheralNotConnected` if the peripheral is not connected.
    /// - Throws: `BlePeripheralProxyError.characteristicNotFound` if the characteristic with the specified UUID cannot be found.
    /// - Throws: `BlePeripheralProxyError.writeNotSupported` if the characteristic does not support writing without a response.
    ///
    /// - Note: This method is useful for sending data where a response from the peripheral is not required, such as sending notifications or control commands.
    public func writeWithoutResponse(data: Data, to characteristicUUID: CBUUID) throws {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            throw BlePeripheralProxyError.peripheralNotConnected
        }
        
        guard let characteristic = getCharacteristic(characteristicUUID) else {
            throw BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)
        }
        
        guard characteristic.properties.contains(.writeWithoutResponse) else {
            throw BlePeripheralProxyError.writeNotSupported(characteristicUUID: characteristicUUID)
        }

        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)

    }
    
    // MARK: - Private
    
    private func buildSubscription(
        characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval,
        callback: @escaping (Result<Void, Error>) -> Void
    ) -> Subscription<Void> {
        characteristicWriteRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BlePeripheralProxyError.writeTimeout(characteristicUUID: characteristicUUID)))
            }
        )
    }
    
    private func write(
        data: Data,
        to characteristicUUID: CBUUID,
        subscription: Subscription<Void>
    ) {
        
        var resultToNotify: Result<Void, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                characteristicWriteRegistry.notify(subscription: subscription, value: result)
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

        guard characteristic.properties.contains(.write) else {
            resultToNotify = .failure(BlePeripheralProxyError.writeNotSupported(characteristicUUID: characteristicUUID))
            return
        }

        // Begin monitoring characteristic write timeout.
        subscription.start()

        // Write data onto the characteristic.
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        
    }
    
}
