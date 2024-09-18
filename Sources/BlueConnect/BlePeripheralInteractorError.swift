//
//  BlePeripheralInteractor.swift
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

import Foundation

/// An enum representing various errors that can occur during interactions with a BLE peripheral.
///
/// `BlePeripheralInteractorError` defines different types of errors encountered during BLE operations, such as missing characteristics, connectivity issues, or unsupported operations.
public enum BlePeripheralInteractorError: Error {
    
    /// The specified characteristic was not found on the peripheral.
    ///
    /// This error is triggered when an operation attempts to access a characteristic that doesn't exist.
    case characteristicNotFound
    
    /// The specified characteristic does not contain any data.
    ///
    /// This error occurs when a read operation finds the characteristic but it contains no valid data.
    case characteristicDataIsNil
    
    /// The peripheral interactor instance has been destroyed and is no longer usable.
    ///
    /// This error indicates that the peripheral interactor object was deallocated or invalidated.
    case destroyed
    
    /// The requested operation (read/write/notify) is not supported by the characteristic or peripheral.
    ///
    /// This error is raised when the peripheral does not support a requested operation, such as writing or enable notifying on a characteristic.
    case operationNotSupported
    
    /// The BLE peripheral is not connected, and operations cannot be performed.
    ///
    /// This error occurs when a BLE operation is attempted but the peripheral is not connected.
    case peripheralNotConnected
    
    /// The specified service was not found on the peripheral.
    ///
    /// This error is triggered when a service that the operation requires is missing from the peripheral.
    case serviceNotFound
    
    /// The operation timed out before it could complete.
    ///
    /// This error occurs when a BLE operation exceeds the allowed time limit.
    case timeout
    
}
