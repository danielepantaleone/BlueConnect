//
//  BlePeripheralProxy.swift
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

import CoreBluetooth
import Foundation

/// An enumeration representing various errors that can occur while interacting with a BLE peripheral via the `BlePeripheralProxy`.
///
/// `BlePeripheralProxyError` is used to signal specific error conditions that arise during BLE operations such as reading, writing,
/// notifying, or discovering services and characteristics.
public enum BlePeripheralProxyError: Error {
    
    /// The specified characteristic was not found on the peripheral.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic that could not be found.
    ///
    /// This error occurs when the desired characteristic is unavailable on the connected peripheral.
    case characteristicNotFound(characteristicUUID: CBUUID)
    
    /// The specified characteristic does not contain any data.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic whose data is `nil`.
    ///
    /// This error is thrown when a characteristic is found, but the data it contains is `nil`.
    case characteristicDataIsNil(characteristicUUID: CBUUID)
    
    /// The peripheral proxy instance has been destroyed and is no longer usable.
    ///
    /// This error occurs if an operation is attempted on a peripheral proxy instance that has been deallocated or is no longer valid.
    case destroyed
    
    /// The BLE peripheral is not connected, and operations cannot be performed.
    ///
    /// This error occurs when trying to perform an action on a peripheral that is not currently connected.
    case peripheralNotConnected
    
    /// The specified service was not found on the peripheral.
    ///
    /// - Parameter serviceUUID: The UUID of the service that could not be found.
    ///
    /// This error is thrown when the required service is unavailable on the connected peripheral.
    case serviceNotFound(serviceUUID: CBUUID)
    
    /// Notify is not supported on the characteristic.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic that does not support notifications.
    ///
    /// This error occurs when the characteristic does not support notifications.
    case notifyNotSupported(characteristicUUID: CBUUID)
    
    /// The set notify operation timed out before it could complete.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic for which the notification operation timed out.
    ///
    /// This error occurs when attempting to enable or disable notifications and the operation exceeds the expected time limit.
    case notifyTimeout(characteristicUUID: CBUUID)
    
    /// Reading data from the characteristic is not supported.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic that does not support reading.
    ///
    /// This error is thrown when the characteristic does not support reading operations.
    case readNotSupported(characteristicUUID: CBUUID)
    
    /// The read operation timed out before it could complete.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic for which the read operation timed out.
    ///
    /// This error occurs when a read operation takes too long to return data.
    case readTimeout(characteristicUUID: CBUUID)
    
    /// Writing data to the characteristic is not supported.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic that does not support writing.
    ///
    /// This error occurs when the characteristic does not support writing operations.
    case writeNotSupported(characteristicUUID: CBUUID)
    
    /// The write operation timed out before it could complete.
    ///
    /// - Parameter characteristicUUID: The UUID of the characteristic for which the write operation timed out.
    ///
    /// This error occurs when a write operation exceeds the allowed time limit.
    case writeTimeout(characteristicUUID: CBUUID)
    
}
