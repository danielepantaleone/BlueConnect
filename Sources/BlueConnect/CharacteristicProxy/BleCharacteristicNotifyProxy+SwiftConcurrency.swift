//
//  BleCharacteristicNotifyProxy+SwiftConcurrency.swift
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

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

public extension BleCharacteristicNotifyProxy {
    
    /// A Boolean value indicating whether notifications are enabled for the characteristic.
    ///
    /// This property asynchronously discovers the characteristic and checks if notifications are active.
    ///
    /// - Throws: An error if the discovery process fails.
    /// - Returns: A Boolean value: `true` if notifications are enabled; otherwise, `false`.
    var isNotifying: Bool {
        get async throws {
            return try await isNotifying(timeout: .seconds(10))
        }
    }
    
    /// Asynchronously checks whether notifications are currently enabled for the characteristic.
    ///
    /// This method  checks the `isNotifying` flag of a characteristic on a connected peripheral. If the peripheral is not connected,
    /// the characteristic is not found, or it does not support notifications, the method will throw an appropriate error.
    ///
    /// - Parameter timeout: The maximum duration to wait for the notification state check. Defaults to 10 seconds. *(Note: currently unused in implementation)*.
    ///
    /// - Returns: `true` if notifications are enabled for the characteristic; `false` otherwise.
    /// - Throws: An error if the peripheral is not connected, the characteristic is not found, or notification is not supported.
    func isNotifying(timeout: DispatchTimeInterval = .seconds(10)) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            isNotifying(timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    /// Enable or disable notifications for the characteristic.
    ///
    /// This method enables or disables notifications for the characteristic on the BLE peripheral.
    /// If the characteristic has not yet been discovered, it will first be discovered and then have
    /// its notification state modified.
    ///
    /// - Parameters:
    ///   - enabled: A boolean indicating whether to enable (true) or disable (false) notifications.
    ///   - timeout: The time interval to wait for the notify operation before it times out. Defaults to 10 seconds.
    ///
    /// - Returns: A boolean indicating whether the notification was successfully enabled (true) or disabled (false).
    /// - Throws: An error if the characteristic cannot be discovered or notify state changed within the specified timeout.
    @discardableResult
    func setNotify(enabled: Bool, timeout: DispatchTimeInterval = .seconds(10)) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            setNotify(enabled: enabled, timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
    }
    
}
