//
//  BlePeripheralManagerProxy+Characteristics.swift
//  BlueConnect
//
//  GitHub Repo and Documentation: https://github.com/danielepantaleone/BlueConnect
//
//  Copyright © 2025 Daniele Pantaleone. All rights reserved.
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

extension BlePeripheralManagerProxy {
    
    /// Responds to a read or write request from a central device.
    ///
    /// This method sends a response to the central that made the read or write request on a characteristic.
    ///
    /// - Parameters:
    ///   - request: The `CBATTRequest` object representing the read or write request.
    ///   - result: The result of the request, specified by `CBATTError.Code`.
    public func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        peripheralManager.respond(to: request, withResult: result)
    }

    /// Sends an updated value to subscribed centrals for a characteristic.
    ///
    /// Updates the characteristic's value and notifies any subscribed centrals.
    ///
    /// - Parameters:
    ///   - value: The data to be sent.
    ///   - characteristic: The `CBMutableCharacteristic` for which the update is sent.
    ///   - centrals: An optional array of `BleCentral` instances representing the subscribed centrals.
    ///
    /// - Returns: `true` if the update was successfully queued; otherwise, `false`.
    public func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [BleCentral]?) -> Bool {
        peripheralManager.updateValue(value, for: characteristic, onSubscribedCentrals: centrals)
    }
    
}
