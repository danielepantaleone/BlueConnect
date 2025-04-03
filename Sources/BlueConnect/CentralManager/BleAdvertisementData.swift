//
//  BleAdvertisementData.swift
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

/// A convenience class that helps interpret and access Bluetooth Low Energy (BLE) advertisement data.
///
/// The `BleAdvertisementData` struct simplifies access to the advertisement data provided by BLE peripherals during discovery.
/// It wraps CoreBluetooth's advertisement data dictionary and provides convenient properties to extract specific data points.
public struct BleAdvertisementData {
    
    // MARK: - Properties
    
    /// The raw advertisement data dictionary containing all the information advertised by the peripheral.
    ///
    /// This dictionary contains key-value pairs as defined by CoreBluetooth, which includes various types of advertisement information.
    public let raw: [String: Any]
    
    // MARK: - Initialization
    
    /// Initializes a new `BleAdvertisementData` instance using CoreBluetooth's advertisement data dictionary.
    ///
    /// This initializer allows you to create a `BleAdvertisementData` instance from the advertisement data provided by
    /// the CoreBluetooth framework during peripheral discovery.
    ///
    /// - Parameter advertisementData: The CoreBluetooth advertisement data dictionary.
    public init(_ advertisementData: [String: Any]) {
        self.raw = advertisementData
    }
    
    // MARK: - Computed Properties
    
    /// A Boolean value indicating whether the peripheral is connectable.
    ///
    /// This property returns `true` if the advertisement data indicates that the peripheral's advertising event type is connectable.
    /// If the event type is not connectable, this property returns `false`.
    public var isConnectable: Bool {
        return (raw[CBAdvertisementDataIsConnectable] as? Bool) == true
    }
    
    /// The local name of the peripheral.
    ///
    /// This property returns a string containing the local name of the peripheral, if available in the advertisement data.
    public var localName: String? {
        return raw[CBAdvertisementDataLocalNameKey] as? String
    }
    
    /// The manufacturer-specific data of the peripheral.
    ///
    /// This property returns a `Data` object containing the manufacturer data, if provided in the advertisement data.
    public var manufacturerData: Data? {
        return raw[CBAdvertisementDataManufacturerDataKey] as? Data
    }
    
    /// The service-specific advertisement data.
    ///
    /// This property returns a dictionary where the keys are `CBUUID` objects representing service UUIDs, and the values
    /// are `Data` objects containing service-specific data. If no service-specific data is present, this property returns `nil`.
    public var serviceData: [CBUUID: Data]? {
        return raw[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
    }
    
    /// The array of service UUIDs being advertised by the peripheral.
    ///
    /// This property returns an array of `CBUUID` objects representing the services advertised by the peripheral.
    /// If no service UUIDs are advertised, this property returns `nil`.
    public var serviceUUIDs: [CBUUID]? {
        return raw[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }
    
    /// The array of service UUIDs found in the "overflow" area of the advertisement data.
    ///
    /// Some advertisement data may overflow the normal advertising packet, and this property returns an array of `CBUUID` objects
    /// representing services that were found in the overflow area. If no overflow service UUIDs are present, this property returns `nil`.
    public var overflowServiceUUIDs: [CBUUID]? {
        return raw[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
    }
    
    /// The transmit power level of the peripheral.
    ///
    /// This property returns an `NSNumber` object containing the transmit (Tx) power level of the peripheral, if advertised.
    /// The Tx power level can be used along with the received signal strength indicator (RSSI) to calculate the path loss.
    public var txPowerLevel: NSNumber? {
        return raw[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
    }
    
    /// The array of solicited service UUIDs.
    ///
    /// This property returns an array of `CBUUID` objects representing services that the peripheral is soliciting.
    /// If no solicited service UUIDs are advertised, this property returns `nil`.
    public var solicitedServiceUUIDs: [CBUUID]? {
        return raw[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
    }
    
}
