//
//  BleCentralManager.swift
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

/// A protocol to mimic the capabilities of a `CBCentralManager`.
///
/// The `BleCentralManager` protocol, along with `BleCentralManagerDelegate`, is designed to make BLE interactions unit testable by abstracting away the hardware-specific behaviors of `CBCentralManager`.
///
/// This protocol can be adopted by mock objects to simulate BLE central manager behavior in tests, enabling controlled and repeatable testing of BLE operations without requiring a physical device.
///
/// - Note: `CBCentralManager` conforms to `BleCentralManager`.
public protocol BleCentralManager: AnyObject {
    
    // MARK: - Properties
    
    /// The current authorization status for using Bluetooth.
    ///
    /// This property reflects the app's authorization to use Bluetooth features.
    var authorization: CBManagerAuthorization { get }
    
    /// The delegate object that you want to receive central manager events.
    ///
    /// Set this delegate to listen for events related to Bluetooth central manager operations, such as connection status and discovery of peripherals.
    var centraManagerDelegate: BleCentralManagerDelegate? { get set }
    
    /// The current state of the central manager.
    ///
    /// This property reflects the current state of the Bluetooth central manager (e.g., powered on, off, etc.).
    var state: CBManagerState { get }
    
    /// Whether or not the central manager is currently scanning for peripherals.
    ///
    /// Returns `true` if the central manager is actively scanning for peripherals; otherwise, `false`.
    var isScanning: Bool { get }
    
    // MARK: - Functions
    
    /// Establishes a connection to a peripheral.
    ///
    /// This method attempts to connect to a specified BLE peripheral. You can pass an optional dictionary to customize
    /// the behavior of the connection.
    ///
    /// - Parameters:
    ///   - peripheral: The peripheral to which the central manager is attempting to connect.
    ///   - options: A dictionary to customize the behavior of the connection.
    func connect(_ peripheral: BlePeripheral, options: [String: Any]?)
    
    /// Cancels an active or pending connection to a peripheral.
    ///
    /// This method terminates a connection or cancels an ongoing connection attempt to a specified peripheral.
    ///
    /// - Parameters:
    ///   - peripheral: The peripheral to which the central manager is either trying to connect or has already connected.
    func cancelConnection(_ peripheral: BlePeripheral)
    
    /// Retrieve all the peripherals with the corresponding identifiers.
    ///
    /// This method retrieves previously connected peripherals with specific identifiers.
    ///
    /// - Parameters:
    ///   - identifiers: A list of peripheral identifiers (represented by `UUID` objects) from which peripheral objects can be retrieved.
    ///
    /// - Returns: A list of objects implementing the `BlePeripheral` protocol.
    func retrievePeripherals(withIds identifiers: [UUID]) -> [BlePeripheral]
    
    /// Retrieves all peripherals that are connected to the system and implement any of the services listed in serviceUUIDs.
    ///
    /// This method returns peripherals that are currently connected to the system and offer specific services.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: A list of service UUIDs (represented by `CBUUID` objects) to filter connected peripherals.
    ///
    /// - Returns: A list of objects implementing the `BlePeripheral` protocol.
    func retrieveConnectedPeripherals(withServiceIds serviceUUIDs: [CBUUID]) -> [BlePeripheral]
    
    /// Starts scanning for peripherals that are advertising any of the services listed in `serviceUUIDs`.
    ///
    /// This method initiates scanning for BLE peripherals advertising the specified services.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: A list of `CBUUID` objects representing the services to scan for.
    ///   - options: An optional dictionary specifying options for the scan.
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    
    /// Stops scanning for peripherals.
    ///
    /// This method stops any ongoing scanning for peripherals.
    func stopScan()
    
}

// MARK: - BleCentralManager + Defaults

public extension BleCentralManager {
    
    /// Establishes a local connection to a peripheral.
    ///
    /// This method connects to a peripheral using the provided options or default behavior if no options are specified.
    ///
    /// - Parameters:
    ///   - peripheral: The peripheral to which the central manager is attempting to connect.
    ///   - options: A dictionary to customize the behavior of the connection, defaults to `nil`.
    func connect(_ peripheral: BlePeripheral, options: [String: Any]? = nil) {
        connect(peripheral, options: options)
    }
    
    /// Scans for peripherals that are advertising services.
    ///
    /// This method starts scanning for peripherals that advertise the specified services or for any advertising peripherals if no services are specified.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: A list of `CBUUID` objects representing the services to scan for, defaults to `nil`.
    ///   - options: An optional dictionary specifying options for the scan, defaults to `nil`.
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]? = nil, options: [String: Any]? = nil) {
        scanForPeripherals(withServices: serviceUUIDs, options: options)
    }
    
}

// MARK: - CBCentralManager + BleCentralManager

extension CBCentralManager: BleCentralManager {
    
    public var centraManagerDelegate: BleCentralManagerDelegate? {
        get { delegate as? BleCentralManagerDelegate }
        set { delegate = newValue }
    }
    
    public func cancelConnection(_ peripheral: BlePeripheral) {
        guard let cbPeripheral = peripheral as? CBPeripheral else { return }
        cancelPeripheralConnection(cbPeripheral)
    }
    
    public func connect(_ peripheral: BlePeripheral, options: [String: Any]? = nil) {
        guard let cbPeripheral = peripheral as? CBPeripheral else { return }
        connect(cbPeripheral, options: options)
    }
    
    public func retrievePeripherals(withIds identifiers: [UUID]) -> [BlePeripheral] {
        return retrievePeripherals(withIdentifiers: identifiers)
    }
    
    public func retrieveConnectedPeripherals(withServiceIds serviceUUIDs: [CBUUID]) -> [BlePeripheral] {
        return retrieveConnectedPeripherals(withServices: serviceUUIDs)
    }
    
}
