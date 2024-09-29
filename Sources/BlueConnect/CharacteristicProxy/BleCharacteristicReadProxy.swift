//
//  BleCharacteristicReadProxy.swift
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

/// A protocol defining the interaction with a BLE characteristic having read capabilities.
///
/// This protocol provides the essential properties and methods needed to interact with a Bluetooth Low Energy (BLE) characteristic.
/// It requires that conforming types define a specific `ValueType` for the characteristic, and provide access to the UUIDs of the characteristic and its associated service.
///
/// Additionally, it allows access to the `BlePeripheralProxy` managing the peripheral.
public protocol BleCharacteristicReadProxy: BleCharacteristicProxy {
    
    /// Decode the provided data into the proxy's value type.
    ///
    /// This method takes the raw data received from a characteristic and converts it into the value type used by the proxy.
    ///
    /// - Parameters:
    ///   - data: The data received from the characteristic. This is expected to be in a format that can be converted to the proxy's value type.
    ///
    /// - Returns: The decoded value of type `ValueType`, which represents the converted data.
    /// - Throws: An error if the data cannot be decoded into the proxy's value type. The specific error thrown depends on the implementation of the `decode` method.
    func decode(_ data: Data) throws -> ValueType
    
}

public extension BleCharacteristicReadProxy {
    
    /// A publisher that emits updates when the value of the characteristic changes.
    ///
    /// This publisher listens to characteristic value changes and emits a signal with data decoded into the proxy's value type.
    ///
    /// - Note: This publisher filters events to only those corresponding to the current characteristic.
    var didUpdateValuePublisher: AnyPublisher<ValueType, Never> {
        peripheralProxy?.didUpdateValuePublisher
            .filter { $0.characteristic.uuid == characteristicUUID }
            .compactMap { _, data in try? decode(data) }
            .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    }
    
    /// Read the characteristic from the BLE peripheral if no valid cached value is found.
    ///
    /// This method first attempts to discover the characteristic. If the characteristic is successfully discovered, it proceeds to read its value.
    /// If the characteristic value is not found in the cache, the method triggers a read operation.
    /// Upon successfully reading the data, it is decoded into the proxy's value type.
    /// The provided callback is invoked with the result.
    ///
    /// - Parameters:
    ///   - cachePolicy: The cache policy that determines whether the value should be fetched from the peripheral or retrieved from the cache. Defaults to `.never`, meaning the value is always read from the peripheral.
    ///   - timeout: The duration to wait for the characteristic read operation to complete. Defaults to 10 seconds.
    ///   - callback: The closure to execute when the characteristic is read. The closure receives a `Result` containing either the decoded value of type `ValueType` or an `Error`.
    func read(
        cachePolicy: BlePeripheralCachePolicy = .never,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<ValueType, Error>) -> Void
    ) {
        let start: DispatchTime = .now()
        discover(timeout: timeout) { characteristicDiscoveryResult in
            characteristicDiscoveryResult.forwardError(to: callback)
            characteristicDiscoveryResult.onSuccess { characteristic in
                peripheralProxy?.read(
                    characteristicUUID: characteristic.uuid,
                    cachePolicy: cachePolicy,
                    timeout: timeout - start.distance(to: .now())
                ) { readResult in
                    readResult.forwardError(to: callback)
                    readResult.onSuccess { data in
                        do {
                            callback(.success(try decode(data)))
                        } catch {
                            callback(.failure(BleCharacteristicProxyError.decodingError(characteristicUUID: characteristic.uuid, cause: error)))
                        }
                    }
                }
            }
        }
    }
    
}

public extension BleCharacteristicReadProxy where ValueType == Data {
    
    /// Bypass data decoding and return raw data.
    ///
    /// - Parameters:
    ///   - data: The data received from the characteristic.
    ///
    /// - Returns: The characteristic raw data.
    func decode(_ data: Data) throws -> ValueType {
        return data
    }
    
}
