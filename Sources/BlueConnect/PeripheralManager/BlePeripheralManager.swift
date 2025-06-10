//
//  BlePeripheralManager.swift
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

// MARK: - BlePeripheralManager

/// A protocol defining the behaviors of a BLE peripheral manager.
///
/// `BlePeripheralManager` provides an abstraction for managing peripheral operations,
/// such as advertising, adding services, and communicating with connected centrals.
///
/// This protocol allows for mock implementations in testing and decouples BLE management from direct dependency on `CBPeripheralManager`.
///
/// - Note: `CBPeripheralManager` conforms to `BlePeripheralManager`.
public protocol BlePeripheralManager: AnyObject {
    
    // MARK: - Properties
    
    /// The current authorization status of the peripheral manager.
    ///
    /// This indicates whether the app has permission to use Bluetooth.
    var authorization: CBManagerAuthorization { get }
        
    /// The delegate object for handling peripheral manager events.
    ///
    /// This delegate conforms to `BlePeripheralManagerDelegate`, enabling custom responses to events such as advertising status and connection updates.
    var peripheralManagerDelegate: BlePeripheralManagerDelegate? { get set }
    
    /// The current state of the peripheral manager.
    ///
    /// This reflects the Bluetooth state, such as whether Bluetooth is powered on or off.
    var state: CBManagerState { get }
    
    /// A Boolean value indicating whether the peripheral manager is currently advertising.
    ///
    /// Returns `true` if advertising is in progress; otherwise, `false`.
    var isAdvertising: Bool { get }
    
    // MARK: - Functions
    
    /// Starts advertising peripheral data.
    ///
    /// - Parameter advertisementData: A dictionary containing data to advertise, such as service UUIDs and local name.
    func startAdvertising(_ advertisementData: [String: Any]?)

    /// Stops advertising peripheral data.
    ///
    /// Calling this method halts any active advertising by the peripheral manager.
    func stopAdvertising()
    
    /// Sets the desired connection latency for a connected central.
    ///
    /// - Parameters:
    ///   - latency: The desired latency level, specified by `CBPeripheralManagerConnectionLatency`.
    ///   - central: The `BleCentral` instance representing the connected central device.
    func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: BleCentral)

    /// Adds a service to the peripheral manager.
    ///
    /// - Parameter service: A `CBMutableService` instance representing the service to add.
    func add(_ service: CBMutableService)

    /// Removes a service from the peripheral manager.
    ///
    /// - Parameter service: A `CBMutableService` instance representing the service to remove.
    func remove(_ service: CBMutableService)

    /// Removes all services from the peripheral manager.
    ///
    /// This function clears all previously added services.
    func removeAllServices()

    /// Responds to a read or write request from a central device.
    ///
    /// - Parameters:
    ///   - request: The `CBATTRequest` object representing the read or write request.
    ///   - result: The result of the request, specified by `CBATTError.Code`.
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code)

    /// Sends an updated value to subscribed centrals for a characteristic.
    ///
    /// - Parameters:
    ///   - value: The data to be sent.
    ///   - characteristic: The `CBMutableCharacteristic` for which the update is sent.
    ///   - centrals: An optional array of `BleCentral` instances representing the subscribed centrals.
    ///   
    /// - Returns: `true` if the update was successfully queued; otherwise, `false`.
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [BleCentral]?) -> Bool
    
}

// MARK: - BlePeripheralManager + Defaults

public extension BlePeripheralManager {
    
    /// Starts advertising peripheral data with optional advertisement data.
    ///
    /// This default implementation allows starting advertising without specifying `advertisementData`.
    /// If no advertisement data is provided, the peripheral manager will start advertising with default data.
    ///
    /// - Parameter advertisementData: A dictionary containing data to advertise, such as service UUIDs and local name.
    ///   Defaults to `nil`.
    func startAdvertising(_ advertisementData: [String: Any]? = nil) {
        startAdvertising(advertisementData)
    }
    
}

// MARK: - CBPeripheralManager + BlePeripheralManager

extension CBPeripheralManager: BlePeripheralManager {
   
    public var peripheralManagerDelegate: BlePeripheralManagerDelegate? {
        get { delegate as? BlePeripheralManagerDelegate }
        set { delegate = newValue }
    }
    
    public func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: BleCentral) {
        guard let cbCentral = central as? CBCentral else { return }
        setDesiredConnectionLatency(latency, for: cbCentral)
    }
    
    public func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [BleCentral]?) -> Bool {
        updateValue(value, for: characteristic, onSubscribedCentrals: centrals?.compactMap { $0 as? CBCentral })
    }

}
