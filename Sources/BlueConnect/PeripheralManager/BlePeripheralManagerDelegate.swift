//
//  BlePeripheralManagerDelegate.swift
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

/// A delegate protocol to handle events from a `BlePeripheralManager`.
///
/// Conforms to `CBPeripheralManagerDelegate` to facilitate BLE peripheral management.
/// This protocol defines methods to respond to various peripheral events, such as updates to the peripheral’s state, advertising status,
/// and interactions with central devices subscribing to characteristics.
///
/// Implementers of this protocol can respond to BLE events with custom behavior for testing or application logic.
public protocol BlePeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
    
    /// Called when the peripheral manager updates its state.
    ///
    /// - Parameter peripheral: The `BlePeripheralManager` instance whose state has changed.
    func blePeripheralManagerDidUpdateState(_ peripheral: BlePeripheralManager)
    
    /// Called when the peripheral manager starts advertising.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheralManager` instance that started advertising.
    ///   - error: An optional `Error` if advertising failed; `nil` if successful.
    func blePeripheralManagerDidStartAdvertising(_ peripheral: BlePeripheralManager, error: Error?)
    
    /// Called when the peripheral manager is ready to send updates to subscribed centrals.
    ///
    /// - Parameter peripheral: The `BlePeripheralManager` instance ready to update subscribers.
    func blePeripheralManagerIsReady(toUpdateSubscribers peripheral: BlePeripheralManager)
    
    /// Called when a service is added to the peripheral manager.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheralManager` instance that added the service.
    ///   - service: The `CBService` instance that was added.
    ///   - error: An optional `Error` if adding the service failed; `nil` if successful.
    func blePeripheralManager(_ peripheral: BlePeripheralManager, didAdd service: CBService, error: Error?)
    
    /// Called when a central device subscribes to a characteristic.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheralManager` instance managing the connection.
    ///   - central: The subscribing `BleCentral` instance.
    ///   - characteristic: The `CBCharacteristic` to which the central subscribed.
    func blePeripheralManager(_ peripheral: BlePeripheralManager, central: BleCentral, didSubscribeTo characteristic: CBCharacteristic)
    
    /// Called when a central device unsubscribes from a characteristic.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheralManager` instance managing the connection.
    ///   - central: The `BleCentral` instance that unsubscribed.
    ///   - characteristic: The `CBCharacteristic` from which the central unsubscribed.
    func blePeripheralManager(_ peripheral: BlePeripheralManager, central: BleCentral, didUnsubscribeFrom characteristic: CBCharacteristic)
    
    /// Called when a read request is received from a central device.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheralManager` instance that received the request.
    ///   - request: The `CBATTRequest` containing details of the read request.
    func blePeripheralManager(_ peripheral: BlePeripheralManager, didReceiveRead request: CBATTRequest)
    
    /// Called when write requests are received from a central device.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheralManager` instance that received the requests.
    ///   - requests: An array of `CBATTRequest` instances representing the write requests.
    func blePeripheralManager(_ peripheral: BlePeripheralManager, didReceiveWrite requests: [CBATTRequest])
    
    /// Called when the peripheral manager is restoring its state.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheralManager` instance restoring its state.
    ///   - dict: A dictionary containing state information to restore the peripheral manager.
    func blePeripheralManager(_ peripheral: BlePeripheralManager, willRestoreState dict: [String: Any])
    
}

public extension BlePeripheralManagerDelegate {
    func blePeripheralManagerDidUpdateState(_ peripheral: BlePeripheralManager) { }
    func blePeripheralManagerDidStartAdvertising(_ peripheral: BlePeripheralManager, error: Error?) { }
    func blePeripheralManagerIsReady(toUpdateSubscribers peripheral: BlePeripheralManager) { }
    func blePeripheralManager(_ peripheral: BlePeripheralManager, didAdd service: CBService, error: Error?) { }
    func blePeripheralManager(_ peripheral: BlePeripheralManager, central: BleCentral, didSubscribeTo characteristic: CBCharacteristic) { }
    func blePeripheralManager(_ peripheral: BlePeripheralManager, central: BleCentral, didUnsubscribeFrom characteristic: CBCharacteristic) { }
    func blePeripheralManager(_ peripheral: BlePeripheralManager, didReceiveRead request: CBATTRequest) { }
    func blePeripheralManager(_ peripheral: BlePeripheralManager, didReceiveWrite requests: [CBATTRequest]) { }
    func blePeripheralManager(_ peripheral: BlePeripheralManager, willRestoreState dict: [String: Any]) { }
}
