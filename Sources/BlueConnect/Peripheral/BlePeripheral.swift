//
//  BlePeripheral.swift
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

/// A protocol to mimic the capabilities of a `CBPeripheral`.
///
/// The `BlePeripheral` protocol, along with `BlePeripheralDelegate`, is designed to make BLE interactions unit testable by abstracting away the hardware-specific behaviors of `CBPeripheral`.
///
/// This protocol can be adopted by mock objects to simulate BLE peripheral behavior in tests, enabling controlled and repeatable testing of BLE operations without requiring a physical device.
///
/// - Note: `CBPeripheral` conforms to `BlePeripheral`.
public protocol BlePeripheral: AnyObject, Sendable {
    
    // MARK: - Properties
    
    /// The unique identifier of the BLE peripheral.
    var identifier: UUID { get }
    
    /// The name of the BLE peripheral. This may be `nil` if the peripheral has not advertised a name.
    var name: String? { get }
    
    /// The current connection state of the BLE peripheral.
    var state: CBPeripheralState { get }
    
    /// A list of `CBService` objects discovered on the peripheral. This will be `nil` until services have been discovered.
    var services: [CBService]? { get }
    
    /// The delegate object that receives peripheral events. This should be set to an object conforming to `BlePeripheralDelegate`.
    var peripheralDelegate: BlePeripheralDelegate? { get set }
    
    // MARK: - Functions
    
    /// Discovers the specified services of the peripheral. If the `serviceUUIDs` parameter is nil, this method attempts to discover all available services on the peripheral.
    ///
    /// - Parameter serviceUUIDs: An optional array of `CBUUID` objects representing the service UUIDs to discover. If `nil`, all services are discovered.
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    
    /// Discovers the specified characteristics for a given service on the peripheral.
    ///
    /// - Parameters:
    ///   - characteristicUUIDs: An optional array of `CBUUID` objects representing the characteristic UUIDs to discover.
    ///   - service: The `CBService` object for which characteristics should be discovered.
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService)
    
    /// Returns the maximum amount of data, in bytes, that can be sent to a characteristic in a single write operation of a given type.
    ///
    /// - Parameter type: The type of write operation, specified by `CBCharacteristicWriteType`.
    /// - Returns: The maximum length, in bytes, that can be sent in a single write operation.
    func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int
    
    /// Reads the current RSSI (Received Signal Strength Indicator) value for the peripheral, while connected.
    func readRSSI()
    
    /// Retrieves the value of a specified characteristic from the peripheral.
    ///
    /// - Parameter characteristic: The `CBCharacteristic` whose value is to be read.
    func readValue(for characteristic: CBCharacteristic)
    
    /// Enables or disables notifications or indications for a specified characteristic.
    ///
    /// - Parameters:
    ///   - enabled: A Boolean value indicating whether notifications or indications should be enabled (`true`) or disabled (`false`).
    ///   - characteristic: The `CBCharacteristic` for which notifications or indications should be set.
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)
    
    /// Writes a value to a specified characteristic on the peripheral.
    ///
    /// - Parameters:
    ///   - data: The data to write to the characteristic.
    ///   - characteristic: The `CBCharacteristic` to which the data should be written.
    ///   - type: The type of write operation, specified by `CBCharacteristicWriteType`. For example, `.withResponse` or `.withoutResponse`.
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType)
    
}

#if $RetroactiveAttribute
extension CBPeripheral: @retroactive @unchecked Sendable { }
#else
extension CBPeripheral: @unchecked Sendable { }
#endif

extension CBPeripheral: BlePeripheral {
   
    public var peripheralDelegate: BlePeripheralDelegate? {
        get { self.delegate as? BlePeripheralDelegate }
        set { self.delegate = newValue }
    }
    
}
