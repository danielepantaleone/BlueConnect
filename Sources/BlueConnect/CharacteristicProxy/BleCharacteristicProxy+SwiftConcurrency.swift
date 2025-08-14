//
//  BleCharacteristicProxy+SwiftConcurrency.swift
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

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

public extension BleCharacteristicProxy {
    
    /// Discover the service and then characteristic.
    ///
    /// - Parameter timeout: The timeout duration for the characteristic discovery operation. Defaults to 10 seconds.
    /// - Throws: An error if the discovery fails within the specified timeout.
    /// - Returns: The discovered `CBCharacteristic`.
    @discardableResult
    func discover(timeout: DispatchTimeInterval = .seconds(10)) async throws -> CBCharacteristic {
        guard let peripheralProxy else {
            throw BlePeripheralProxyError.destroyed
        }
        let start: DispatchTime = .now()
        let service = try await peripheralProxy.discover(
            serviceUUID: serviceUUID,
            timeout: timeout)
        let characteristic = try await peripheralProxy.discover(
            characteristicUUID: characteristicUUID,
            in: service.uuid,
            timeout: timeout - start.distance(to: .now()))
        return characteristic
    }
    
}
