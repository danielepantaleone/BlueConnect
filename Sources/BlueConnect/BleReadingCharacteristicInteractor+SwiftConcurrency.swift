//
//  BleReadingCharacteristicInteractor+SwiftConcurrency.swift
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

public extension BleReadingCharacteristicInteractor {
    
    /// Read the characteristic value according to the provided cache policy.
    ///
    /// This asynchronous method first ensures that the characteristic is discovered.
    /// Once discovered, it reads the characteristic's value based on the specified cache policy.
    /// If the value is cached, it is returned from the cache; otherwise, the method reads it from the BLE peripheral.
    /// The method returns the value decoded into the interactor's `ValueType`.
    ///
    /// - Parameters:
    ///   - policy: The cache policy determining whether the value should be read from the peripheral or retrieved from the cache. Defaults to `.never`, which means that the value is always read directly from the peripheral.
    ///   - timeout: The duration to wait for the characteristic read operation to complete. Defaults to 10 seconds.
    ///
    /// - Returns: The characteristic value decoded into the interactor's `ValueType`.
    /// - Throws: An error if the characteristic cannot be discovered or read within the specified timeout, or if decoding the data fails.
    func read(policy: BlePeripheralCachePolicy = .never, timeout: DispatchTimeInterval = .seconds(10)) async throws -> ValueType {
        try await withCheckedThrowingContinuation { continuation in
            read(policy: policy, timeout: timeout) { result in
                continuation.resume(with: result)
            }
        }
    }
    
}
