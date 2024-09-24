//
//  BleCentralManagerDelegate.swift
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

/// A protocol defining the delegate methods for handling Bluetooth Central Manager events.
///
/// The `BleCentralManagerDelegate` protocol extends `CBCentralManagerDelegate` and provides additional
/// methods for handling central manager updates, connections, discoveries, disconnections, and failures.
///
/// This protocol is typically implemented by objects that need to receive events from a `BleCentralManager`, which wraps CoreBluetooth's `CBCentralManager`.
public protocol BleCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
    
    /// Called when the Bluetooth central manager updates its state.
    ///
    /// This method informs the delegate about any state changes of the Bluetooth central manager, such as
    /// becoming powered on, off, or unsupported.
    ///
    /// - Parameter central: The central manager whose state has been updated.
    func bleCentralManagerDidUpdateState(_ central: BleCentralManager)
    
    /// Called when a connection is successfully established with a peripheral.
    ///
    /// This method notifies the delegate that the central manager has successfully connected to the specified peripheral.
    ///
    /// - Parameters:
    ///   - central: The central manager managing the connection.
    ///   - peripheral: The peripheral to which the central has connected.
    func bleCentralManager(_ central: BleCentralManager, didConnect peripheral: BlePeripheral)
    
    /// Called when a peripheral is discovered during scanning.
    ///
    /// This method notifies the delegate when the central manager discovers a peripheral advertising nearby.
    ///
    /// - Parameters:
    ///   - central: The central manager conducting the scan.
    ///   - peripheral: The discovered peripheral.
    ///   - advertisementData: A `BleAdvertisementData` object containing advertisement data from the peripheral.
    ///   - RSSI: The received signal strength indicator (RSSI) of the discovered peripheral.
    func bleCentralManager(_ central: BleCentralManager, didDiscover peripheral: BlePeripheral, advertisementData: BleAdvertisementData, rssi RSSI: Int)
    
    /// Called when a connection to a peripheral is disconnected.
    ///
    /// This method notifies the delegate when the central manager has disconnected from a peripheral, either
    /// intentionally or due to an error.
    ///
    /// - Parameters:
    ///   - central: The central manager managing the disconnection.
    ///   - peripheral: The peripheral that has been disconnected.
    ///   - error: An optional error object if the disconnection was due to an error, or `nil` if the disconnection was intentional.
    func bleCentralManager(_ central: BleCentralManager, didDisconnectPeripheral peripheral: BlePeripheral, error: Error?)
    
    /// Called when the central manager fails to connect to a peripheral.
    ///
    /// This method informs the delegate when a connection attempt to a peripheral has failed.
    ///
    /// - Parameters:
    ///   - central: The central manager attempting the connection.
    ///   - peripheral: The peripheral that the central failed to connect to.
    ///   - error: An error object describing the reason for the connection failure.
    func bleCentralManager(_ central: BleCentralManager, didFailToConnect peripheral: BlePeripheral, error: Error?)
    
    /// Called when the central manager is about to restore its state.
    ///
    /// This method notifies the delegate that the central manager will restore its state, typically when the app
    /// has been relaunched by the system to continue managing peripherals.
    ///
    /// - Parameters:
    ///   - central: The central manager that is restoring its state.
    ///   - dict: A dictionary containing the preserved state information for the central manager.
    func bleCentralManager(_ central: BleCentralManager, willRestoreState dict: [String: Any])
    
}

public extension BleCentralManagerDelegate {
    func bleCentralManagerDidUpdateState(_ central: BleCentralManager) { }
    func bleCentralManager(_ central: BleCentralManager, didConnect peripheral: BlePeripheral) { }
    func bleCentralManager(_ central: BleCentralManager, didDiscover peripheral: BlePeripheral, advertisementData: BleAdvertisementData, rssi RSSI: Int) { }
    func bleCentralManager(_ central: BleCentralManager, didDisconnectPeripheral peripheral: BlePeripheral, error: Error?) { }
    func bleCentralManager(_ central: BleCentralManager, didFailToConnect peripheral: BlePeripheral, error: Error?) { }
    func bleCentralManager(_ central: BleCentralManager, willRestoreState dict: [String: Any]) { }
}
