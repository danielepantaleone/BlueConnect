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

import CoreBluetooth
import Foundation

/// An enumeration representing errors related to BLE characteristic data handling in the `BleCharacteristicProxy`.
///
/// `BleCharacteristicProxyError` signals issues with encoding or decoding characteristic data during BLE operations,
/// and includes the underlying cause of the error.
public enum BleCharacteristicProxyError: Error {
    
    /// The characteristic proxy successfully retrieved the characteristic data, but data conversion to the expected type failed.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic for which decoding failed.
    ///   - cause: The underlying error that caused the decoding to fail.
    ///
    /// This error occurs when the raw data received from the characteristic cannot be decoded into the format expected by the proxy.
    case decodingError(characteristicUUID: CBUUID, cause: Error)
    
    /// The characteristic proxy failed to encode the characteristic value into the raw data format required for writing to the BLE peripheral.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic for which encoding failed.
    ///   - cause: The underlying error that caused the encoding to fail.
    ///
    /// This error occurs when encoding the characteristic value type into a binary format fails, preventing the data from being sent to the peripheral.
    case encodingError(characteristicUUID: CBUUID, cause: Error)
    
}
