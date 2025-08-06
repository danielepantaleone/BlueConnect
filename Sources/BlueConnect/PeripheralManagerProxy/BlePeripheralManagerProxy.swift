//
//  BlePeripheralManagerProxy.swift
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

import Combine
#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

/// A proxy class to manage a `BlePeripheralManager` instance, providing reactive publishers for various BLE events.
///
/// `BlePeripheralManagerProxy` offers a wrapper around a `BlePeripheralManager`, exposing key properties and providing publishers for Combine-based event handling.
public class BlePeripheralManagerProxy: NSObject, @unchecked Sendable {
    
    // MARK: - Public properties
    
    /// The instance of the `BlePeripheralManager` that this proxy manages.
    public private(set) var peripheralManager: BlePeripheralManager!
    
    /// The current authorization status of the peripheral manager.
    ///
    /// This indicates whether the app has permission to use Bluetooth.
    public var authorization: CBManagerAuthorization { peripheralManager.authorization }
    
    /// The current state of the peripheral manager.
    ///
    /// This reflects the Bluetooth state, such as whether Bluetooth is powered on or off.
    public var state: CBManagerState { peripheralManager.state }
    
    /// A Boolean value indicating whether the peripheral manager is currently advertising.
    ///
    /// Returns `true` if advertising is in progress; otherwise, `false`.
    public var isAdvertising: Bool { peripheralManager.isAdvertising }
    
    // MARK: - Publishers
    
    /// Publisher for state updates of the peripheral manager.
    public var didUpdateStatePublisher: AnyPublisher<CBManagerState, Never> {
        didUpdateStateSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for the advertising status of the peripheral manager that emits a `Bool` value indicating whether the peripheral manager is currently advertising (`true`) or not (`false`).
    public var didUpdateAdvertisingPublisher: AnyPublisher<Bool, Never> {
        didUpdateAdvertisingSubject.eraseToAnyPublisher()
    }
    
    /// Publisher that emits when a service is successfully added or an error occurs during the addition process.
    public var didAddServicePublisher: AnyPublisher<(service: CBService, error: Error?), Never> {
        didAddServiceSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for central subscriptions to a characteristic.
    public var didSubscribeToCharacteristicPublisher: AnyPublisher<CBCharacteristic, Never> {
        didSubscribeToCharacteristicSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for central unsubscriptions from a characteristic.
    public var didUnsubscribeFromCharacteristicPublisher: AnyPublisher<CBCharacteristic, Never> {
        didUnsubscribeFromCharacteristicSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for read requests from centrals.
    public var didReceiveReadRequestPublisher: AnyPublisher<CBATTRequest, Never> {
        didReceiveReadRequestSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for write requests from centrals.
    public var didReceiveWriteRequestsPublisher: AnyPublisher<[CBATTRequest], Never> {
        didReceiveWriteRequestsSubject.eraseToAnyPublisher()
    }
    
    /// Publisher that emits when the peripheral manager is ready to update subscribers.
    public var isReadyToUpdateSubscribersPublisher: AnyPublisher<Void, Never> {
        isReadyToUpdateSubscribersSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for the peripheral manager's restored state.
    public var willRestoreStatePublisher: AnyPublisher<[String: Any], Never> {
        willRestoreStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Internal properties
    
    var advertisingMonitor: DispatchSourceTimer?
    let lock = NSRecursiveLock()
    let startAdvertisingRegistry: ListRegistry<Void> = .init()
    let stopAdvertisingRegistry: ListRegistry<Void> = .init()
    let waitUntilReadyRegistry: ListRegistry<Void> = .init()
    
    let didUpdateStateSubject: PassthroughSubject<CBManagerState, Never> = .init()
    let didUpdateAdvertisingSubject: PassthroughSubject<Bool, Never> = .init()
    let didAddServiceSubject: PassthroughSubject<(service: CBService, error: Error?), Never> = .init()
    let didSubscribeToCharacteristicSubject: PassthroughSubject<CBCharacteristic, Never> = .init()
    let didUnsubscribeFromCharacteristicSubject: PassthroughSubject<CBCharacteristic, Never> = .init()
    let didReceiveReadRequestSubject: PassthroughSubject<CBATTRequest, Never> = .init()
    let didReceiveWriteRequestsSubject: PassthroughSubject<[CBATTRequest], Never> = .init()
    let isReadyToUpdateSubscribersSubject: PassthroughSubject<Void, Never> = .init()
    let willRestoreStateSubject: PassthroughSubject<[String: Any], Never> = .init()
    
    // MARK: - Initialization
    
    /// Unavailable initializer.
    public override init() {
        fatalError("please use other available initializers")
    }
    
    /// Initializes the proxy with the provided `BlePeripheralManager`.
    ///
    /// - Parameter peripheralManager: The `BlePeripheralManager` instance that this proxy will manage.
    ///
    /// - Important: You must use this initializer when running unit tests, passing your mocked `BlePeripheralManager` implementation.
    public init(peripheralManager: BlePeripheralManager) {
        super.init()
        self.peripheralManager = peripheralManager
        self.peripheralManager.peripheralManagerDelegate = self
    }

    /// Initializes the proxy by instantiating a `CBPeripheralManager` using the provided queue and options.
    ///
    /// - Parameters:
    ///   - queue:  The dispatch queue on which the events will be dispatched.
    ///   - options: An optional dictionary specifying options for the `CBCentralManager`.
    ///
    /// - Important: By using this initializer, a `CBPeripheralManager` will be implicitly initialized, so you must not use this initializer when running unit tests.
    public init(queue: DispatchQueue? = nil, options: [String: Any]? = nil) {
        super.init()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: queue, options: options)
        self.peripheralManager.peripheralManagerDelegate = self
    }
    
    /// Perform `BlePeripheralManagerProxy` graceful deinitialization.
    deinit {
        lock.lock()
        defer { lock.unlock() }
        peripheralManager.peripheralManagerDelegate = nil
        // Notify registries about shutdown.
        startAdvertisingRegistry.notifyAll(.failure(BleCentralManagerProxyError.destroyed))
        stopAdvertisingRegistry.notifyAll(.failure(BleCentralManagerProxyError.destroyed))
        // Stop timers
        advertisingMonitor?.cancel()
        advertisingMonitor = nil
    }

}
