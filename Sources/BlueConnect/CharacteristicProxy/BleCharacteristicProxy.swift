//
//  BleCharacteristicProxy.swift
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

/// A protocol defining the interaction with a BLE characteristic.
///
/// This protocol provides the essential properties and methods needed to interact with a Bluetooth Low Energy (BLE) characteristic.
/// It requires that conforming types define a specific `ValueType` for the characteristic, and provide access to the UUIDs of the characteristic and its associated service.
///
/// Additionally, it allows access to the `BlePeripheralProxy` managing the peripheral.
public protocol BleCharacteristicProxy {
    
    /// Associated type representing the value of the BLE characteristic.
    associatedtype ValueType
    
    /// The UUID of the characteristic this proxy works with.
    var characteristicUUID: CBUUID { get }
    
    /// The UUID of the service containing the characteristic.
    var serviceUUID: CBUUID { get }
    
    /// A weak reference to the `BlePeripheralProxy` managing the peripheral associated with this characteristic.
    var peripheralProxy: BlePeripheralProxy? { get }
    
}

// MARK: - Characteristic discovery

public extension BleCharacteristicProxy {
    
    /// Discover the service and then characteristic.
    ///
    /// If the service or the characteristic have already been discovered, local cached values will be used.
    ///
    /// - Parameters:
    ///   - timeout: The timeout duration for the characteristic discovery operation. Defaults to 10 seconds.
    ///   - callback: A closure to execute when the characteristic is discovered. This closure receives a `Result<CBCharacteristic, Error>` where the success case contains the discovered characteristic and the failure case contains an error.
    func discover(timeout: DispatchTimeInterval = .seconds(10), callback: @escaping (Result<CBCharacteristic, Error>) -> Void) {
        let start: DispatchTime = .now()
        peripheralProxy?.discover(serviceUUID: serviceUUID, timeout: timeout) { serviceDiscoveryResult in
            serviceDiscoveryResult.forwardError(to: callback)
            serviceDiscoveryResult.onSuccess { _ in
                peripheralProxy?.discover(
                    characteristicUUID: characteristicUUID,
                    in: serviceUUID,
                    timeout: timeout - start.distance(to: .now()),
                    callback: { characteristicDiscoveryResult in
                        characteristicDiscoveryResult.forwardError(to: callback)
                        characteristicDiscoveryResult.forwardSuccess(to: callback)
                    }
                )
            }
        }
    }
    
}
