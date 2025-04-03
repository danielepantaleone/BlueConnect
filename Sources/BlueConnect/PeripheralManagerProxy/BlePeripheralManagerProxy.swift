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
@preconcurrency import CoreBluetooth
import Foundation

/// A proxy class to manage a `BlePeripheralManager` instance, providing reactive publishers for various BLE events.
///
/// `BlePeripheralManagerProxy` offers a wrapper around a `BlePeripheralManager`, exposing key properties and providing publishers for Combine-based event handling.
public class BlePeripheralManagerProxy: NSObject {
    
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

// MARK: - Advertising

extension BlePeripheralManagerProxy {
    
    /// Starts advertising peripheral data.
    ///
    /// Initiates advertising of the peripheral's services and other provided advertisement data. The method ensures that the peripheral manager is in a powered-on state before starting the advertising process. A callback is invoked with the result of the operation, either success or an error.
    ///
    /// - Parameters:
    ///   - advertisementData: A dictionary containing data to advertise, such as service UUIDs and the local name. Defaults to `nil` if no advertisement data is provided.
    ///   - timeout: The time interval to wait for the advertising to start before timing out. Defaults to `.never`, meaning no timeout is applied.
    ///   - callback: A closure that is called with the result of the advertising operation. The closure is passed a `Result` type, which is `.success` on successful advertising start or `.failure` with an error if the operation fails. Defaults to a no-op closure.
    public func startAdvertising(
        _ advertisementData: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never,
        callback: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Ensure peripheral manager is in a powered-on state.
        guard peripheralManager.state == .poweredOn else {
            callback(.failure(BlePeripheralManagerProxyError.invalidState(peripheralManager.state)))
            return
        }
        
        // Exit early if already advertising.
        guard !isAdvertising else {
            callback(.success(()))
            return
        }
        
        // Register a callback to be notified when advertising is started.
        startAdvertisingRegistry.register(
            callback: callback,
            timeout: timeout
        ) {
            $0.notify(.failure(BlePeripheralManagerProxyError.advertisingTimeout))
        }
        
        // Try to start advertising.
        peripheralManager.startAdvertising(advertisementData)
        
    }

    /// Stops advertising peripheral data.
    ///
    /// Calling this method halts any active advertising by the peripheral manager, stopping the broadcast of services and advertisement data.
    ///
    /// - Parameter callback: A closure that is called with the result of the stop advertising operation. The closure is passed a `Result` type, which is `.success` on successful advertising stop or `.failure` with an error if the operation fails. Defaults to a no-op closure.
    public func stopAdvertising(callback: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Ensure peripheral manager is in a powered-on state.
        guard peripheralManager.state == .poweredOn else {
            callback(.failure(BlePeripheralManagerProxyError.invalidState(peripheralManager.state)))
            return
        }
        
        // Exit early if not advertising.
        guard isAdvertising else {
            callback(.success(()))
            return
        }
        
        // If we do not have an advertising monitor running (very unlikely) we have to provide early feeback.
        guard advertisingMonitor == nil || advertisingMonitor!.isCancelled else {
            peripheralManager.stopAdvertising()
            callback(.success(()))
            return
        }
        
        // Register a callback to be notified when advertising is stopped.
        stopAdvertisingRegistry.register(callback: callback) {
            $0.notify(.failure(BlePeripheralManagerProxyError.advertisingTimeout))
        }
        
        // Try to stop advertising.
        peripheralManager.stopAdvertising()
        
    }
    
}

// MARK: - Services management

extension BlePeripheralManagerProxy {
    
    /// Adds a service to the peripheral manager.
    ///
    /// Registers a `CBMutableService` with the peripheral manager, making the service available for centrals to discover and interact with.
    ///
    /// - Parameter service: A `CBMutableService` instance representing the service to add.
    public func add(_ service: CBMutableService) {
        peripheralManager.add(service)
    }
    
    /// Adds a list of services to the peripheral manager.
    ///
    /// Registers a list of `CBMutableService` with the peripheral manager, making the all the services available for centrals to discover and interact with.
    ///
    /// - Parameter services: A list of `CBMutableService` instance representing the services to add.
    public func add(services: [CBMutableService]) {
        for service in services {
            peripheralManager.add(service)
        }
    }

    /// Removes a service from the peripheral manager.
    ///
    /// Unregisters a previously added service, making it unavailable for centrals.
    ///
    /// - Parameter service: A `CBMutableService` instance representing the service to remove.
    public func remove(_ service: CBMutableService) {
        peripheralManager.remove(service)
    }
    
    /// Removes a list services from the peripheral manager.
    ///
    /// Unregisters previously added services, making them unavailable for centrals.
    ///
    /// - Parameter servicew: A list of `CBMutableService` instance representing the services to remove.
    public func remove(services: [CBMutableService]) {
        for service in services {
            peripheralManager.remove(service)
        }
    }

    /// Removes all services from the peripheral manager.
    ///
    /// This function clears all previously added services, ensuring no services are available for discovery by centrals.
    public func removeAllServices() {
        peripheralManager.removeAllServices()
    }
    
}

// MARK: - Characteristic interaction

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

// MARK: - State change

extension BlePeripheralManagerProxy {
    
    /// Waits until the peripheral manager is in the `.poweredOn` state, executing the callback upon success or failure.
    ///
    /// This method registers a callback that is invoked when the peripheral manager's state changes to `.poweredOn`, or an error occurs.
    /// The method also verifies that the peripheral manager is authorized and supported.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(10)) { result in
    ///     switch result {
    ///         case .success:
    ///             print("Peripheral manager is ready")
    ///         case .failure(let error):
    ///             print("Peripheral manager is not ready: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - timeout: The maximum time to wait for the peripheral manager to become ready. Default is `.never`.
    ///   - callback: A closure that receives a `Result` indicating success or an error if the peripheral manager is unauthorized or unsupported.
    ///
    /// - Note: If the state is already `.poweredOn`, the callback is called immediately with success.
    public func waitUntilReady(timeout: DispatchTimeInterval = .never, callback: @escaping ((Result<Void, Error>) -> Void)) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Ensure peripheral manager is not already powered on.
        guard peripheralManager.state != .poweredOn else {
            callback(.success(()))
            return
        }
        
        // Ensure peripheral manager is authorized.
        guard peripheralManager.state != .unauthorized else {
            callback(.failure(BlePeripheralManagerProxyError.invalidState(.unauthorized)))
            return
        }
        
        // Ensure peripheral manager is supported.
        guard peripheralManager.state != .unsupported else {
            callback(.failure(BlePeripheralManagerProxyError.invalidState(.unsupported)))
            return
        }
        
        // Register a callback to be notified when peripheral manager is powered on.
        waitUntilReadyRegistry.register(
            callback: callback,
            timeout: timeout
        ) {
            $0.notify(.failure(BlePeripheralManagerProxyError.readyTimeout))
        }
        
    }
    
}
