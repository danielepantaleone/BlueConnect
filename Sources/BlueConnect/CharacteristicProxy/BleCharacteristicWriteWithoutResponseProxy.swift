//
//  BleCharacteristicWriteWithoutResponseProxy.swift
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

/// A protocol defining the ability to write data to a BLE characteristic without expecting a response.
///
/// This protocol includes an `encode` method that allows for converting the proxy's `ValueType` into a raw `Data`
/// representation to be written onto a BLE characteristic without waiting for a confirmation response from the peripheral.
public protocol BleCharacteristicWriteWithoutResponseProxy: BleCharacteristicProxy {
 
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

public extension BleCharacteristicWriteWithoutResponseProxy {
    
    /// Write a value to a characteristic without waiting for a response from the BLE peripheral.
    ///
    /// This method first discovers the characteristic and then writes the provided value without expecting a response.
    /// The encoded data is sent to the BLE peripheral for the characteristic identified by the proxy.
    ///
    /// - Parameters:
    ///   - value: The value to encode and write to the characteristic.
    ///   - timeout: The timeout for the characteristic write operation. Defaults to 10 seconds.
    ///   - callback: An optional closure to call once the write operation is attempted. It returns either a success or failure.
    func writeWithoutResponse(
        value: ValueType,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: ((Result<Void, Error>) -> Void)? = nil
    ) {
        discover(timeout: timeout) { result in
            result.forwardError(to: callback)
            result.onSuccess { characteristic in
                do {
                    try peripheralProxy?.writeWithoutResponse(
                        data: try encode(value),
                        to: characteristic.uuid)
                    callback?(.success(()))
                } catch {
                    callback?(.failure(BleCharacteristicProxyError.encodingError(characteristicUUID: characteristic.uuid, cause: error)))
                }
            }
        }
    }
    
}

public extension BleCharacteristicWriteWithoutResponseProxy where ValueType == Data {
    
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
