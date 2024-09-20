//
//  BleCharacteristicProxyError.swift
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

/// An struct representing various errors that can occur during interactions with a BLE characteristic.
///
/// `BleCharacteristicProxyError` encapsulates various error categories that might occur during BLE characteristic interactions.
/// It provides detailed information about the nature of the error, including an optional underlying error and a descriptive message.
public struct BleCharacteristicProxyError: Error {
    
    // MARK: - Category

    /// An enumeration defining different categories of errors that can occur during BLE peripheral interactions.
    public enum Category {
        /// The characteristic interactor correctly retrieved characteristic data but data conversion towards characteristic managed type failed.
        case decodingError
        /// The characteristic interactor didn't manage to encode characteristic value type into raw data to be written on the BLE peripheral.
        case encodingError
    }
    
    // MARK: - Properties

    /// The category of the error, indicating the type of issue encountered.
    public internal(set) var category: Category
    /// An optional descriptive message providing additional context about the error.
    public internal(set) var message: String?
    /// The underlying error that caused this error, if any.
    public internal(set) var cause: Error?
    
    // MARK: - Initialization
    
    /// Initializes a new instance of `BleCharacteristicProxyError`.
    ///
    /// - Parameters:
    ///   - category: The category of the error, describing the type of issue encountered.
    ///   - message: An optional descriptive message providing additional context about the error.
    ///   - cause: An optional underlying error that provides more details about the cause of the error.
    public init(category: Category, message: String? = nil, cause: Error? = nil) {
        self.category = category
        self.cause = cause
        self.message = message
    }
    
}
