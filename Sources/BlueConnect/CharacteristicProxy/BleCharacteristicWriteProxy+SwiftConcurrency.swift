//
//  BleCharacteristicWriteProxy+SwiftConcurrency.swift
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

public extension BleCharacteristicWriteProxy {
    
    /// Write characteristic value asynchronously.
    ///
    /// This method first discovers the characteristic and then attempts to write the provided value to it.
    /// If the write operation fails or encounters an error, an error will be thrown.
    /// If the operation succeeds, the method completes without returning a value.
    ///
    /// - Parameters:
    ///   - value: The value to write to the characteristic. This value will be encoded before writing.
    ///   - timeout: The timeout duration for the write operation. Defaults to 10 seconds.
    ///
    /// - Throws: An error if the characteristic cannot be discovered, the value cannot be encoded, or the write operation fails.
    func write(value: ValueType, timeout: DispatchTimeInterval = .seconds(10)) async throws {
        try await withCheckedThrowingContinuation { continuation in
            write(value: value, timeout: timeout) { result in
                continuation.resume(with: result)
            }
        }
    }
    
}
