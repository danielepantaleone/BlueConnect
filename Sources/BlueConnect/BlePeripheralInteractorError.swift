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

/// A struct representing errors related to interactions with a BLE peripheral.
///
/// `BlePeripheralInteractorError` encapsulates various error categories that might occur during BLE peripheral interactions.
/// It provides detailed information about the nature of the error, including an optional underlying error and a descriptive message.
public struct BlePeripheralInteractorError: Error {
    
    // MARK: - Category
    
    /// An enumeration defining different categories of errors that can occur during BLE peripheral interactions.
    public enum Category {
        /// The specified characteristic was not found on the peripheral.
        case characteristicNotFound
        /// The specified characteristic does not contain any data.
        case characteristicDataIsNil
        /// The peripheral interactor instance has been destroyed and is no longer usable.
        case destroyed
        /// The requested operation (read/write/notify) is not supported by the characteristic or peripheral.
        case operationNotSupported
        /// The BLE peripheral is not connected, and operations cannot be performed.
        case peripheralNotConnected
        /// The specified service was not found on the peripheral.
        case serviceNotFound
        /// The operation timed out before it could complete.
        case timeout
    }
    
    // MARK: - Properties
    
    /// The category of the error, indicating the type of issue encountered.
    public internal(set) var category: Category
    /// The underlying error that caused this error, if any.
    public internal(set) var internalError: Error?
    /// An optional descriptive message providing additional context about the error.
    public internal(set) var message: String?
    
    // MARK: - Initialization
    
    /// Initializes a new instance of `BlePeripheralInteractorError`.
    ///
    /// - Parameters:
    ///   - category: The category of the error, describing the type of issue encountered.
    ///   - internalError: An optional underlying error that provides more details about the cause of the error.
    ///   - message: An optional descriptive message providing additional context about the error.
    public init(category: Category, internalError: Error? = nil, message: String? = nil) {
        self.category = category
        self.internalError = internalError
        self.message = message
    }
    
}
