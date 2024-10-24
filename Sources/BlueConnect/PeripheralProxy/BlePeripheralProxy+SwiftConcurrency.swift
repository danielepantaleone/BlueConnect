//
//  BlePeripheralProxy+SwiftConcurrency.swift
//  BlueConnect
//
//  GitHub Repo and Documentation: https://github.com/danielepantaleone/BlueConnect
//
//  Copyright © 2024 Daniele Pantaleone. All rights reserved.
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

@preconcurrency import CoreBluetooth
import Foundation

public extension BlePeripheralProxy {
    
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
    func discover(
        serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> CBService {
        try await withCheckedThrowingContinuation { continuation in
            discover(serviceUUID: serviceUUID, timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
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
    func discover(
        characteristicUUID: CBUUID,
        in serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> CBCharacteristic {
        try await withCheckedThrowingContinuation { continuation in
            discover(characteristicUUID: characteristicUUID, in: serviceUUID, timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
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
    func read(
        characteristicUUID: CBUUID,
        cachePolicy: BlePeripheralCachePolicy,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            read(characteristicUUID: characteristicUUID, cachePolicy: cachePolicy, timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
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
    func write(
        data: Data,
        to characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            write(data: data, to: characteristicUUID, timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
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
    func setNotify(
        enabled: Bool,
        for characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10)
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            setNotify(enabled: enabled, for: characteristicUUID, timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
    }
    
}
