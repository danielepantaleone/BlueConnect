//
//  BlePeripheralDelegate.swift
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

/// A protocol extending `CBPeripheralDelegate` to provide additional functionality for unit testing BLE peripherals.
///
/// The purpose of `BlePeripheralDelegate` is to mock BLE peripheral operations, enabling tests for Bluetooth Low Energy (BLE) interactions without needing real hardware.
///
/// By conforming to `BlePeripheralDelegate`, objects can simulate a BLE peripheral's behavior, allowing controlled testing of peripheral operations such as reading and writing
/// characteristics, discovering services, and handling updates to RSSI and characteristics. This protocol includes methods corresponding to BLE operations that occur during
/// communication with a peripheral.
///
/// Conforms to: `CBPeripheralDelegate`
///
public protocol BlePeripheralDelegate: CBPeripheralDelegate {
    
    /// Called when the BLE peripheral's name has been updated.
    ///
    /// - Parameter peripheral: The mock `BlePeripheral` that updated its name.
    func blePeripheralDidUpdateName(_ peripheral: BlePeripheral)
    
    /// Called when the BLE peripheral's RSSI (Received Signal Strength Indicator) is updated.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that updated its RSSI.
    ///   - error: An optional error if the operation failed.
    func blePeripheralDidUpdateRSSI(_ peripheral: BlePeripheral, error: Error?)
    
    /// Called when the BLE peripheral has discovered the characteristics for a specific service.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that discovered the characteristics.
    ///   - service: The `CBService` for which characteristics were discovered.
    ///   - error: An optional error if the discovery operation failed.
    func blePeripheral(_ peripheral: BlePeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    
    /// Called when the BLE peripheral has discovered included services for a specific service.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that discovered included services.
    ///   - service: The `CBService` for which included services were discovered.
    ///   - error: An optional error if the discovery operation failed.
    func blePeripheral(_ peripheral: BlePeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?)
    
    /// Called when the BLE peripheral has discovered its available services.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that discovered its services.
    ///   - error: An optional error if the discovery operation failed.
    func blePeripheral(_ peripheral: BlePeripheral, didDiscoverServices error: Error?)
    
    /// Called when the services of the BLE peripheral are modified.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` whose services were modified.
    ///   - invalidatedServices: An array of invalidated `CBService` objects.
    func blePeripheral(_ peripheral: BlePeripheral, didModifyServices invalidatedServices: [CBService])
    
    /// Called when the BLE peripheral has read its RSSI value.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that read its RSSI.
    ///   - RSSI: The current RSSI value as an `NSNumber`.
    ///   - error: An optional error if the operation failed.
    func blePeripheral(_ peripheral: BlePeripheral, didReadRSSI RSSI: NSNumber, error: Error?)
    
    /// Called when the BLE peripheral has updated the notification state for a characteristic.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that updated the notification state.
    ///   - characteristic: The `CBCharacteristic` whose notification state was updated.
    ///   - error: An optional error if the operation failed.
    func blePeripheral(_ peripheral: BlePeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    
    /// Called when the BLE peripheral has updated the value for a characteristic.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that updated the characteristic value.
    ///   - characteristic: The `CBCharacteristic` whose value was updated.
    ///   - error: An optional error if the operation failed.
    func blePeripheral(_ peripheral: BlePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    
    /// Called when the BLE peripheral has written a value to a characteristic.
    ///
    /// - Parameters:
    ///   - peripheral: The mock `BlePeripheral` that wrote the value.
    ///   - characteristic: The `CBCharacteristic` to which the value was written.
    ///   - error: An optional error if the operation failed.
    func blePeripheral(_ peripheral: BlePeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
    
}

extension BlePeripheralDelegate {
    public func blePeripheralDidUpdateName(_ peripheral: BlePeripheral) { }
    public func blePeripheralDidUpdateRSSI(_ peripheral: BlePeripheral, error: Error?) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didDiscoverServices error: Error?) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didModifyServices invalidatedServices: [CBService]) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didReadRSSI RSSI: NSNumber, error: Error?) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) { }
    public func blePeripheral(_ peripheral: BlePeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) { }
}
