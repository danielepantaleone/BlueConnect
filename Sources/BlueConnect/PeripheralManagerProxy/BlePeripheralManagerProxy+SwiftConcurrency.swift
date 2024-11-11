//
//  BlePeripheralManagerProxy+SwiftConcurrency.swift
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

extension BlePeripheralManagerProxy {
    
    /// Waits asynchronously until the peripheral manager is in the `.poweredOn` state, or throws an error if the state is unauthorized or unsupported.
    ///
    /// This method uses an async/await pattern to wait for the peripheral manager to become ready. It checks the peripheral manager's state and resumes
    /// with success if it is already `.poweredOn`. Otherwise, it waits until the state changes to `.poweredOn` within the specified timeout.
    /// If the state is unauthorized or unsupported, it throws an error.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// do {
    ///     try await peripheralManagerProxy.waitUntilReady(timeout: .seconds(5))
    ///     // Peripheral manager is ready
    /// } catch {
    ///     // Handle error (e.g., unsupported or unauthorized state)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - timeout: The maximum duration to wait for the peripheral manager to be ready. The default value is `.never`, indicating no timeout.
    ///
    /// - Returns: The method returns asynchronously when the peripheral manager is ready or an error occurs.
    /// - Throws: An error if the it's not possible to wait for the peripheral manager to be ready within the provided timeout.
    public func waitUntilReady(timeout: DispatchTimeInterval = .never) async throws {
        try await withCheckedThrowingContinuation { continuation in
            waitUntilReady(timeout: timeout) { result in
                globalQueue.async {
                    continuation.resume(with: result)
                }
            }
        }
    }
    
}
