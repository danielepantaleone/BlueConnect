//
//  BleCentralManagerInteractor+SwiftConcurrency.swift
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
import CoreBluetooth
import Foundation

extension BleCentralManagerInteractor {
    
    /// Connects to a specified BLE peripheral asynchronously.
    ///
    /// This method attempts to establish a connection to the given `BlePeripheral` using the provided options and within the specified timeout period.
    /// If the peripheral is already connected, the method will succeed immediately. If a timeout is specified and the connection is not established within
    /// that period, an error will be thrown.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to connect to.
    ///   - options: An optional dictionary of connection options. Defaults to `nil`.
    ///   - timeout: The maximum amount of time to wait for the connection. Defaults to `.never`, meaning no timeout.
    ///
    /// - Returns: The method returns asynchronously when the connection is successfully established or an error occurs.
    /// - Throws: An error if the connection fails or if the operation times out.
    public func connect(
        peripheral: BlePeripheral,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connect(peripheral: peripheral, options: options, timeout: timeout) { result in
                continuation.resume(with: result)
            }
        }
    }
    
}
