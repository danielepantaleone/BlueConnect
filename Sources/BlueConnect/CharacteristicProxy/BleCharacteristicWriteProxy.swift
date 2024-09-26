//
//  BleCharacteristicWriteProxy.swift
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

/// A protocol defining the interaction with a BLE characteristic having write capabilities.
///
/// This protocol includes an `encode` method that allows for converting the proxy's `ValueType` into a raw `Data`
/// representation to be written onto a BLE characteristic.
public protocol BleCharacteristicWriteProxy: BleCharacteristicProxy {
 
    /// Encode data using the proxy's information.
    ///
    /// This method converts the `ValueType` of the proxy into a raw `Data` representation suitable for writing to the BLE characteristic.
    /// The encoded data will be written to the characteristic on the BLE peripheral.
    ///
    /// - Parameters:
    ///   - value: The value of the proxy's `ValueType` to encode.
    ///
    /// - Returns: The raw data representation of the provided value, ready to be written onto the characteristic.
    /// - Throws: An error if encoding the value fails.
    func encode(_ value: ValueType) throws -> Data
    
}

public extension BleCharacteristicWriteProxy {
    
    /// A publisher that emits a value when the characteristic's value is successfully written.
    ///
    /// This publisher listens to write operations for characteristics and emits a signal when the write operation completes successfully.
    ///
    /// - Note: This publisher filters events to only those corresponding to the current characteristic.
    var didWriteValuePublisher: AnyPublisher<Void, Never>? {
        peripheralProxy?.didWriteValuePublisher
            .filter { $0.uuid == characteristicUUID }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Write a value to the characteristic and notify the result via the provided callback.
    ///
    /// This method discovers the characteristic and then attempts to write the provided value to it.
    /// If the write operation fails, an error will be reported through the callback.
    /// The callback will also be invoked if the write operation succeeds.
    ///
    /// - Parameters:
    ///   - value: The value to write to the characteristic. This value will be encoded before writing.
    ///   - timeout: The timeout duration for the write operation. Defaults to 10 seconds.
    ///   - callback: An optional closure to execute when the write operation completes. It will receive a `Result` indicating success or failure.
    func write(
        value: ValueType,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let start: DispatchTime = .now()
        discover(timeout: timeout) { result in
            result.forwardError(to: callback)
            result.onSuccess { characteristic in
                do {
                    let data = try encode(value)
                    peripheralProxy?.write(
                        data: data,
                        to: characteristic.uuid,
                        timeout: timeout - start.distance(to: .now())
                    ) { writeResult in
                        writeResult.forwardError(to: callback)
                        writeResult.forwardSuccess(to: callback)
                    }
                } catch {
                    callback?(.failure(BleCharacteristicProxyError(category: .encodingError, cause: error)))
                }
            }
        }
    }
    
}

public extension BleCharacteristicWriteProxy where ValueType == Data {
    
    /// Bypass data encoding and return raw data.
    ///
    /// - Parameters:
    ///   - value: The data to write on the characteristic
    ///
    /// - Returns: The raw data representation of the provided value, ready to be written onto the characteristic.
    func encode(_ value: Data) throws -> Data {
        return value
    }
    
}
