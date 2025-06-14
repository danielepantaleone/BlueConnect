//
//  BleCharacteristicNotifyProxy.swift
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

import Combine
#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

/// A protocol representing a proxy that handles notifications for a BLE characteristic.
public protocol BleCharacteristicNotifyProxy: BleCharacteristicProxy {
    
}

public extension BleCharacteristicNotifyProxy {
    
    /// A publisher that emits the notification state (enabled or disabled) of the characteristic.
    ///
    /// This publisher will emit values when the notification state of the characteristic changes.
    ///
    /// - Note: This publisher filters events to only those corresponding to the current characteristic.
    var didUpdateNotificationStatePublisher: AnyPublisher<Bool, Never> {
        peripheralProxy?.didUpdateNotificationStatePublisher
            .filter { $0.characteristic.uuid == characteristicUUID }
            .map { _, enabled in enabled }
            .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    }
    
    /// Checks whether notification is enabled for the characteristic.
    ///
    /// This method verifies if the `isNotifying` flag is set for a characteristic on a connected peripheral.
    /// If the peripheral is not connected, the characteristic is not found, or the characteristic does not support notifications, the method will return a corresponding error via the callback.
    ///
    /// - Parameters:
    ///   - timeout: The timeout duration for the notification check operation. If the operation does not complete within this time, it will fail.
    ///   - callback: A closure to execute when the characteristic notification state is retrieved. The closure receives a `Result` indicating success or failure, with the current notification state as a success value.
    func isNotifying(
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Bool, Error>) -> Void
    ) {
        let start: DispatchTime = .now()
        discover(timeout: timeout) { characteristicDiscoveryResult in
            characteristicDiscoveryResult.forwardError(to: callback)
            characteristicDiscoveryResult.onSuccess { characteristic in
                peripheralProxy?.isNotifying(
                    characteristicUUID: characteristic.uuid,
                    timeout: timeout - start.distance(to: .now()),
                    callback: { notifyResult in
                        notifyResult.forwardError(to: callback)
                        notifyResult.forwardSuccess(to: callback)
                    }
                )
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
    ///   - callback: A closure that will be executed once the notify operation completes. It provides a `Result` with either the updated notification state (enabled or disabled) or an error.
    func setNotify(
        enabled: Bool,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: ((Result<Bool, Error>) -> Void)? = nil
    ) {
        let start: DispatchTime = .now()
        discover(timeout: timeout) { characteristicDiscoveryResult in
            characteristicDiscoveryResult.forwardError(to: callback)
            characteristicDiscoveryResult.onSuccess { characteristic in
                peripheralProxy?.setNotify(
                    enabled: enabled,
                    for: characteristic.uuid,
                    timeout: timeout - start.distance(to: .now()),
                    callback: { notifyResult in
                        notifyResult.forwardError(to: callback)
                        notifyResult.forwardSuccess(to: callback)
                    }
                )
            }
        }
    }
    
}
