//
//  BleCentralManagerProxy.swift
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
import CoreBluetooth
import Foundation

/// `BleCentralManagerProxy` provides a higher-level abstraction for managing BLE peripherals via `BleCentralManager`.
///
/// This class uses Combine publishers to emit updates on BLE-related events, such as peripheral discovery, peripheral connection/disconnection and state updates.
public class BleCentralManagerProxy: NSObject {
    
    // MARK: - Public properties
    
    /// The instance of the `BleCentralManager` that this interactor manages.
    public private(set) var centralManager: BleCentralManager!
    
    /// A publisher that emits the updated state of the BLE central manager.
    public lazy var didUpdateStatePublisher: AnyPublisher<CBManagerState, Never> = {
        didUpdateStateSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when a BLE peripheral successfully connects.
    public lazy var didConnectPublisher: AnyPublisher<BlePeripheral, Never> = {
        didConnectSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when the central manager will restore its state.
    public lazy var willRestoreStatePublisher: AnyPublisher<[String: Any], Never> = {
        willRestoreStateSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when a peripheral is discovered, including its advertisement data and signal strength (RSSI).
    public lazy var didDiscoverPublisher: AnyPublisher<(peripheral: BlePeripheral, advertisementData: BleAdvertisementData, rssi: NSNumber), Never> = {
        didDiscoverSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when a peripheral disconnects, optionally including an error if the disconnection was unexpected.
    public lazy var didDisconnectPublisher: AnyPublisher<(peripheral: BlePeripheral, error: Error?), Never> = {
        didDisconnectSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when the central manager fails to connect to a peripheral, optionally including the error that occurred.
    public lazy var didFailToConnectPublisher: AnyPublisher<(peripheral: BlePeripheral, error: Error?), Never> = {
        didFailToConnectSubject.eraseToAnyPublisher()
    }()
    
    // MARK: - Internal properties
    
    var connectionCallbacks: [UUID: [(Result<Void, Error>) -> Void]] = [:]
    var connectionTimers: [UUID: DispatchSourceTimer] = [:]
    var disconnectionCallbacks: [UUID: [(Result<Void, Error>) -> Void]] = [:]
    let mutex = RecursiveMutex()
    
    lazy var didUpdateStateSubject: PassthroughSubject<CBManagerState, Never> = .init()
    lazy var didConnectSubject: PassthroughSubject<BlePeripheral, Never> = .init()
    lazy var didDiscoverSubject: PassthroughSubject<(peripheral: BlePeripheral, advertisementData: BleAdvertisementData, rssi: NSNumber), Never> = .init()
    lazy var didDisconnectSubject: PassthroughSubject<(peripheral: BlePeripheral, error: Error?), Never> = .init()
    lazy var didFailToConnectSubject: PassthroughSubject<(peripheral: BlePeripheral, error: Error?), Never> = .init()
    lazy var willRestoreStateSubject: PassthroughSubject<[String: Any], Never> = .init()
    
    // MARK: - Initialization
    
    /// Unavailable initializer. Use `init(centralManager:)` instead.
    public override init() {
        fatalError("use init(centralManager:)")
    }
    
    /// Initializes the interactor with the provided `BleCentralManager`.
    ///
    /// - Parameter centralManager: The `BleCentralManager` instance that this interactor will manage.
    public init(centralManager: BleCentralManager) {
        super.init()
        self.centralManager = centralManager
        self.centralManager.centraManagerDelegate = self
    }
    
    // MARK: - Internal methods
    
    /// Registers a callback for a peripheral, associating it with the peripheral's UUID.
    ///
    /// - Parameters:
    ///   - store: The callback store to register the callback in.
    ///   - uuid: The UUID of the peripheral.
    ///   - callback: The callback to register.
    func registerCallback<T>(
        store: inout [UUID: [(Result<T, Error>) -> Void]],
        uuid: UUID,
        callback: ((Result<T, Error>) -> Void)?
    ) {
        guard let callback else { return }
        if store[uuid] == nil {
            store[uuid] = []
        }
        store[uuid]?.append(callback)
    }
    
    /// Notifies all registered callbacks for a peripheral and clears the callbacks.
    ///
    /// - Parameters:
    ///   - store: The callback store to notify.
    ///   - uuid: The UUID of the peripheral.
    ///   - value: The result to pass to the callbacks.
    func notifyCallbacks<T>(
        store: inout [UUID: [(Result<T, Error>) -> Void]],
        uuid: UUID,
        value: Result<T, Error>
    ) {
        guard let callbacks = store[uuid] else {
            return
        }
        store[uuid] = []
        callbacks.forEach { $0(value) }
    }
}

// MARK: - Peripheral connection

extension BleCentralManagerProxy {
    
    /// Initiates a connection to a BLE peripheral with optional timeout and callback for result notification.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// bleCentralManagerProxy.connect(peripheral: peripheral, timeout: .seconds(10)) { result in
    ///     switch result {
    ///         case .success:
    ///             print("Successfully connected to peripheral")
    ///         case .failure(let error):
    ///             print("Failed to connect: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to connect to.
    ///   - options: A dictionary of options to customize the connection behavior, such as `CBConnectPeripheralOptionNotifyOnConnectionKey`. Defaults to `nil`.
    ///   - timeout: A `DispatchTimeInterval` specifying how long to wait before considering the connection as failed due to timeout. Defaults to `.never`, meaning no timeout.
    ///   - callback: An optional closure called with a `Result<Void, Error>` indicating the success or failure of the connection attempt. If the connection is successful,
    ///     `.success(())` is passed. If it fails, `.failure(Error)` is passed with an appropriate error.
    ///
    /// - Note: If the peripheral is already in a `.connected` state, the callback is immediately invoked with success.
    /// - Note: If the peripheral is already in the process of connecting (`.connecting` state), the method does not reinitiate the connection.
    public func connect(
        peripheral: BlePeripheral,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never,
        callback: ((Result<Void, Error>) -> Void)? = nil
    ) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Ensure central manager is in a powered-on state
        guard centralManager.state == .poweredOn else {
            callback?(.failure(BleCentralManagerProxyError(category: .invalidState(centralManager.state))))
            return
        }
        
        // If already connected, notify success
        guard peripheral.state != .connected else {
            callback?(.success(()))
            return
        }
        
        registerCallback(
            store: &connectionCallbacks,
            uuid: peripheral.identifier,
            callback: callback)
        
        startConnectionTimer(
            peripheralIdentifier: peripheral.identifier,
            timeout: timeout)
        
        // If already connecting, no need to reinitiate connection
        guard peripheral.state != .connecting else {
            return
        }
        
        // Initiate connection
        centralManager.connect(peripheral, options: options)
        
    }
    
}

// MARK: - Peripheral disconnection

extension BleCentralManagerProxy {
    
    /// Disconnects a BLE peripheral and optionally notifies via a callback when the operation completes.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// bleCentralManagerProxy.disconnect(peripheral: peripheral) { result in
    ///     switch result {
    ///         case .success:
    ///             print("Successfully disconnected")
    ///         case .failure(let error):
    ///             print("Failed to disconnect: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to disconnect.
    ///   - callback: An optional closure that is called with a `Result<Void, Error>`, providing success or failure of the disconnection attempt.
    ///     If the disconnection is successful, `.success(())` is passed. If the operation fails, `.failure(Error)` is passed with an appropriate error.
    ///
    /// - Note: If the peripheral is already in a `.disconnected` state, the callback is immediately called with success.
    /// - Note: If the peripheral is already in the process of disconnecting (`.disconnecting` state), the method does not reinitiate the disconnection.
    public func disconnect(peripheral: BlePeripheral, callback: ((Result<Void, Error>) -> Void)? = nil) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Ensure central manager is in a powered-on state
        guard centralManager.state == .poweredOn else {
            callback?(.failure(BleCentralManagerProxyError(category: .invalidState(centralManager.state))))
            return
        }
        
        // If already disconnected, notify success
        guard peripheral.state != .disconnected else {
            callback?(.success(()))
            return
        }
        
        registerCallback(
            store: &disconnectionCallbacks,
            uuid: peripheral.identifier,
            callback: callback)

        // If already disconnecting, no need to reinitiate disconnection
        guard peripheral.state != .disconnecting else {
            return
        }
        
        // Initiate disconnection
        centralManager.cancelConnection(peripheral)
        
    }
    
}

// MARK: - Timers

extension BleCentralManagerProxy {
    
    func startConnectionTimer(peripheralIdentifier: UUID, timeout: DispatchTimeInterval) {
        mutex.lock()
        defer { mutex.unlock() }
        guard timeout != .never else {
            connectionTimers[peripheralIdentifier]?.cancel()
            connectionTimers[peripheralIdentifier] = nil
            return
        }
        connectionTimers[peripheralIdentifier]?.cancel()
        connectionTimers[peripheralIdentifier] = DispatchSource.makeTimerSource()
        connectionTimers[peripheralIdentifier]?.schedule(deadline: .now() + timeout, repeating: .never)
        connectionTimers[peripheralIdentifier]?.setEventHandler { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            // Kill the timer and reset
            connectionTimers[peripheralIdentifier]?.cancel()
            connectionTimers[peripheralIdentifier] = nil
            // If the peripheral is not in disconnected state we disconnect it else it will connect at some point.
            if let peripheral = centralManager.retrievePeripherals(withIds: [peripheralIdentifier]).first,
                peripheral.state != .disconnected,
                centralManager.state == .poweredOn {
                disconnect(peripheral: peripheral) { [weak self] _ in
                    guard let self else { return }
                    notifyCallbacks(
                        store: &connectionCallbacks,
                        uuid: peripheralIdentifier,
                        value: .failure(BleCentralManagerProxyError(category: .timeout)))
                }
            } else { // The peripheral could not be retrieved or it's already disconnected
                notifyCallbacks(
                    store: &connectionCallbacks,
                    uuid: peripheralIdentifier,
                    value: .failure(BleCentralManagerProxyError(category: .timeout)))
            }
        }
        connectionTimers[peripheralIdentifier]?.resume()
    }
    
    func stopConnectionTimer(peripheralIdentifier: UUID) {
        mutex.lock()
        defer { mutex.unlock() }
        connectionTimers[peripheralIdentifier]?.cancel()
        connectionTimers[peripheralIdentifier] = nil
    }
    
}

// MARK: - BleCentralManagerDelegate conformance

extension BleCentralManagerProxy: BleCentralManagerDelegate {
    
    public func bleCentralManagerDidUpdateState(_ central: BleCentralManager) {
        didUpdateStateSubject.send(central.state)
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didConnect peripheral: BlePeripheral) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Stop timer
        stopConnectionTimer(peripheralIdentifier: peripheral.identifier)
        // Notify publisher
        didConnectSubject.send(peripheral)
        // Notify registered callbacks
        notifyCallbacks(
            store: &connectionCallbacks,
            uuid: peripheral.identifier,
            value: .success(()))
        
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didDisconnectPeripheral peripheral: BlePeripheral, error: Error?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Notify publisher
        didDisconnectSubject.send((peripheral, error))
        // Notify registered callbacks (only if disconnection initiated by calling disconnect()
        notifyCallbacks(
            store: &disconnectionCallbacks,
            uuid: peripheral.identifier,
            value: .success(()))
        
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didFailToConnect peripheral: BlePeripheral, error: Error?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Stop timer
        stopConnectionTimer(peripheralIdentifier: peripheral.identifier)
        // Notify publisher
        didFailToConnectSubject.send((peripheral, error))
        // Notify registered callbacks
        notifyCallbacks(
            store: &connectionCallbacks,
            uuid: peripheral.identifier,
            value: .failure(error ?? BleCentralManagerProxyError(category: .unknown)))
        
    }
    
    public func bleCentralManager(_ central: BleCentralManager, willRestoreState dict: [String: Any]) {
        willRestoreStateSubject.send(dict)
    }
    
}
