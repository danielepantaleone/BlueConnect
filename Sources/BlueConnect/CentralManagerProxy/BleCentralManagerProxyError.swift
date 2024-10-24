//
//  BleCentralManagerProxyError.swift
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

/// An enumeration representing various errors that can occur in the `BleCentralManagerProxy`.
///
/// `BleCentralManagerProxyError` is used to signal specific error conditions that arise when interacting with
/// the central manager proxy, such as connection timeouts, invalid states, or unknown issues.
public enum BleCentralManagerProxyError: Error {
    
    /// Indicates that a timeout occurred during peripheral connection.
    ///
    /// This error is thrown when a peripheral connection attempt exceeds the allowed time limit.
    case connectionTimeout
    
    /// The central manager proxy instance has been destroyed and is no longer usable.
    ///
    /// This error occurs if an operation is attempted on a central manager proxy instance that has been deallocated or is no longer valid.
    case destroyed
    
    /// Indicates that the central manager is in an invalid state for the requested operation.
    ///
    /// - Parameter state: The invalid `CBManagerState` that prevented the operation from proceeding.
    case invalidState(CBManagerState)
    
    /// Represents an unknown error condition.
    ///
    /// This error is used when an unrecognized or unspecified issue occurs within the central manager proxy.
    case unknown
    
}
