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
@preconcurrency import CoreBluetooth
import Foundation

/// `BleCentralManagerProxy` provides a higher-level abstraction for managing BLE peripherals via `BleCentralManager`.
///
/// This class uses Combine publishers to emit updates on BLE-related events, such as peripheral discovery, peripheral connection/disconnection and state updates.
public class BleCentralManagerProxy: NSObject {
    
    // MARK: - Public properties
    
    /// The instance of the `BleCentralManager` that this proxy manages.
    public private(set) var centralManager: BleCentralManager!
    
    /// The current authorization status for using Bluetooth.
    ///
    /// This property reflects the app's authorization to use Bluetooth features.
    public var authorization: CBManagerAuthorization { centralManager.authorization }
    
    /// Whether or not the central manager is currently scanning for peripherals.
    ///
    /// Returns `true` if the central manager is actively scanning for peripherals; otherwise, `false`.
    public var isScanning: Bool { centralManager.isScanning }
    
    /// The current state of the central manager.
    ///
    /// This property reflects the current state of the Bluetooth central manager (e.g., powered on, off, etc.).
    public var state: CBManagerState { centralManager.state }
    
    // MARK: - Publishers
    
    /// A publisher that emits the updated state of the BLE central manager.
    public var didUpdateStatePublisher: AnyPublisher<CBManagerState, Never> {
        didUpdateStateSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when a BLE peripheral successfully connects.
    public var didConnectPublisher: AnyPublisher<BlePeripheral, Never> {
        didConnectSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when a BLE peripheral disconnects, optionally including an error if the disconnection was unexpected.
    public var didDisconnectPublisher: AnyPublisher<(peripheral: BlePeripheral, error: Error?), Never> {
        didDisconnectSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when the central manager fails to connect to a BLE peripheral, optionally including the error that occurred.
    public var didFailToConnectPublisher: AnyPublisher<(peripheral: BlePeripheral, error: Error), Never> {
        didFailToConnectSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when the central manager will restore its state.
    public var willRestoreStatePublisher: AnyPublisher<[String: Any], Never> {
        willRestoreStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Internal properties
    
    var connectionState: [UUID: CBPeripheralState] = [:]
    var connectionTimeouts: Set<UUID> = []
    let connectionRegistry: KeyedRegistry<UUID, Void> = .init()
    let disconnectionRegistry: KeyedRegistry<UUID, Void> = .init()
    let waitUntilReadyRegistry: ListRegistry<Void> = .init()
   
    var discoverTimer: DispatchSourceTimer?
    var discoverSubject: PassthroughSubject<(
        peripheral: BlePeripheral,
        advertisementData: BleAdvertisementData,
        RSSI: Int), Error>?
    let lock = NSRecursiveLock()
    
    let didUpdateStateSubject: PassthroughSubject<CBManagerState, Never> = .init()
    let didConnectSubject: PassthroughSubject<BlePeripheral, Never> = .init()
    let didDisconnectSubject: PassthroughSubject<(peripheral: BlePeripheral, error: Error?), Never> = .init()
    let didFailToConnectSubject: PassthroughSubject<(peripheral: BlePeripheral, error: Error), Never> = .init()
    let willRestoreStateSubject: PassthroughSubject<[String: Any], Never> = .init()
    
    // MARK: - Initialization
    
    /// Unavailable initializer.
    public override init() {
        fatalError("please use other available initializers")
    }
    
    /// Initializes the proxy with the provided `BleCentralManager`.
    ///
    /// - Parameter centralManager: The `BleCentralManager` instance that this proxy will manage.
    ///
    /// - Important: You must use this initializer when running unit tests, passing your mocked `BleCentralManager` implementation.
    public init(centralManager: BleCentralManager) {
        super.init()
        self.centralManager = centralManager
        self.centralManager.centraManagerDelegate = self
    }

    /// Initializes the proxy by instantiating a `CBCentralManager` using the provided queue and options.
    ///
    /// - Parameters:
    ///   - queue:  The dispatch queue on which the events will be dispatched.
    ///   - options: An optional dictionary specifying options for the `CBCentralManager`.
    ///
    /// - Important: By using this initializer, a `CBCentralManager` will be implicitly initialized, so you must not use this initializer when running unit tests.
    public init(queue: DispatchQueue? = nil, options: [String: Any]? = nil) {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: queue, options: options)
        self.centralManager.centraManagerDelegate = self
    }
    
    /// Perform `BleCentralManagerProxy` graceful deinitialization.
    deinit {
        lock.lock()
        defer { lock.unlock() }
        centralManager.centraManagerDelegate = nil
        // Stop ongoing scan (if any)
        centralManager.stopScan()
        // Notify registries about shutdown.
        connectionRegistry.notifyAll(.failure(BleCentralManagerProxyError.destroyed))
        disconnectionRegistry.notifyAll(.failure(BleCentralManagerProxyError.destroyed))
        waitUntilReadyRegistry.notifyAll(.failure(BleCentralManagerProxyError.destroyed))
        // Stop timers
        discoverTimer?.cancel()
        discoverTimer = nil
        // Notify scan finished
        discoverSubject?.send(completion: .failure(BleCentralManagerProxyError.destroyed))
        discoverSubject = nil
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
    ///   - callback: A closure called with a `Result<Void, Error>` indicating the success or failure of the connection attempt. If the connection is successful,
    ///     `.success(())` is passed. If it fails, `.failure(Error)` is passed with an appropriate error.
    ///
    /// - Note: If the peripheral is already in a `.connected` state, the callback is immediately invoked with success.
    /// - Note: If the peripheral is already in the process of connecting (`.connecting` state), the method does not reinitiate the connection.
    public func connect(
        peripheral: BlePeripheral,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never,
        callback: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Ensure central manager is in a powered-on state
        guard centralManager.state == .poweredOn else {
            callback(.failure(BleCentralManagerProxyError.invalidState(centralManager.state)))
            return
        }
        
        // If already connected, notify success on callback (not on publisher since it's not a new connection)
        guard peripheral.state != .connected else {
            callback(.success(()))
            return
        }
        
        connectionRegistry.register(
            key: peripheral.identifier,
            callback: callback,
            timeout: timeout
        ) { [weak self, weak peripheral] subscription in
            
            guard let self else { return }
            guard let peripheral else { return }
            
            lock.lock()
            defer { lock.unlock() }
            
            // If the peripheral managed to connect somehow, avoid to disconnect it.
            // We assume the connection was already advertised on the callback and combine publisher.
            guard peripheral.state != .connected else {
                return
            }
            
            // We track the connection timeout for this peripheral to trigger the correct
            // callbacks and publisher after disconnecting the peripheral from the central.
            connectionTimeouts.insert(peripheral.identifier)
            
            // We attempt to disconnect the peripheral prior notifying.
            disconnect(peripheral: peripheral) { _ in
                subscription.notify(.failure(BleCentralManagerProxyError.connectionTimeout))
            }
            
        }
        
        // If already connecting, no need to reinitiate connection
        guard peripheral.state != .connecting else {
            return
        }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .connecting
        // Initiate connection.
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
    ///   - callback: A closure called with a `Result<Void, Error>`, providing success or failure of the disconnection attempt.
    ///     If the disconnection is successful, `.success(())` is passed. If the operation fails, `.failure(Error)` is passed with an appropriate error.
    ///
    /// - Note: If the peripheral is already in a `.disconnected` state, the callback is immediately called with success.
    /// - Note: If the peripheral is already in the process of disconnecting (`.disconnecting` state), the method does not reinitiate the disconnection.
    public func disconnect(peripheral: BlePeripheral, callback: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        
        lock.lock()
        defer {lock.unlock() }
                
        // Ensure central manager is in a powered-on state
        guard centralManager.state == .poweredOn else {
            callback(.failure(BleCentralManagerProxyError.invalidState(centralManager.state)))
            return
        }
        
        // If already disconnected, notify success (not on publisher since it's already disconnected)
        guard peripheral.state != .disconnected else {
            callback(.success(()))
            return
        }
        
        // Track disconnection callback in the disconnection registry.
        disconnectionRegistry.register(key: peripheral.identifier, callback: callback)

        // If already disconnecting, no need to reinitiate disconnection.
        guard peripheral.state != .disconnecting else {
            return
        }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .disconnecting
        // Initiate disconnection.
        centralManager.cancelConnection(peripheral)
        
    }
    
}

// MARK: - Peripheral discovery

extension BleCentralManagerProxy {
    
    /// Scans for BLE peripherals with specified services and options.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: An optional array of service UUIDs to filter the scan results. If `nil`, it scans for all available peripherals.
    ///   - options: Optional dictionary of options for customizing the scanning behavior.
    ///   - timeout: The time interval after which the scan should stop automatically. Default is 60 seconds.
    /// - Returns: A publisher that emits `BleCentralManagerScanRecord` instances as peripherals are discovered, and completes or fails on error.
    ///
    /// This function initiates a scan for BLE peripherals. If a scan is already in progress, the existing scan is terminated and a new one is started right after.
    /// The scan is stopped automatically after the specified timeout, or it can be stopped manually by calling `stopScan()`.
    ///
    /// - Note: If the central manager is not in the `.poweredOn` state, the scan fails, and the publisher sends a `.failure` event with an appropriate error.
    public func scanForPeripherals(
        withServices serviceUUIDs: [CBUUID]? = nil,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .seconds(60)
    ) -> AnyPublisher<(
        peripheral: BlePeripheral,
        advertisementData: BleAdvertisementData,
        RSSI: Int
    ), Error> {
                
        lock.lock()
        defer { lock.unlock() }
        
        // If we are already have a subject it means we are already scanning we should already be receiving updates.
        // In this case we notify the completion of previous scan and we start a new one (killing any previous timer).
        discoverTimer?.cancel()
        discoverTimer = nil
        discoverSubject?.send(completion: .finished)
        discoverSubject = nil
        
        // Create a passthrough subject through which manage the whole peripheral discover process.
        let subject: PassthroughSubject<(
            peripheral: BlePeripheral,
            advertisementData: BleAdvertisementData,
            RSSI: Int
        ), Error> = .init()
        
        // Ensure central manager is in a powered-on state.
        guard centralManager.state == .poweredOn else {
            subject.send(completion: .failure(BleCentralManagerProxyError.invalidState(centralManager.state)))
            return subject.eraseToAnyPublisher()
        }
        
        // Store locally to update when timeout expire or on scan stop.
        discoverSubject = subject
        // Start discover timer.
        startDiscoverTimer(timeout: timeout)
        // Initiate discovery.
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        
        return subject.eraseToAnyPublisher()

    }
    
    /// Scans for BLE peripherals with specified services and options.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: An optional array of service UUIDs to filter the scan results. If `nil`, it scans for all available peripherals.
    ///   - options: Optional dictionary of options for customizing the scanning behavior.
    ///   - timeout: The time interval after which the scan should stop automatically. Default is 60 seconds.
    /// - Returns: A publisher that emits `BleCentralManagerScanRecord` instances as peripherals are discovered, and completes or fails on error.
    ///
    /// This function initiates a scan for BLE peripherals returning an `AsyncThrowingStream` that can be used to iterate over discovered peripherals.
    /// The scan is stopped automatically after the specified timeout, or it can be stopped manually by calling `stopScan()`.
    ///
    /// - Note: If the central manager is not in the `.poweredOn` state, the scan fails, and the async stream is finished with an appropriate error.
    public func scanForPeripherals(
        withServices serviceUUIDs: [CBUUID]? = nil,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .seconds(60)
    ) -> AsyncThrowingStream<(
        peripheral: BlePeripheral,
        advertisementData: BleAdvertisementData,
        RSSI: Int
    ), Error> {
        AsyncThrowingStream { continuation in
            final class CancellableBox: @unchecked Sendable {
                var cancellable: AnyCancellable?
            }
            let box = CancellableBox()
            box.cancellable = scanForPeripherals(
                withServices: serviceUUIDs,
                options: options,
                timeout: timeout
            )
            .receive(on: globalQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                        case .finished:
                            continuation.finish()
                        case .failure(let error):
                            continuation.finish(throwing: error)
                    }
                },
                receiveValue: { peripheral, advertisementData, RSSI in
                    continuation.yield((peripheral, advertisementData, RSSI))
                }
            )
            continuation.onTermination = { @Sendable _ in
                box.cancellable?.cancel()
            }
        }
    }
    
    /// Stops the current BLE peripheral scan.
    ///
    /// Stops the  BLE peripherals discovery and completes the scan's publisher with `.finished`.
    public func stopScan() {
        lock.lock()
        defer { lock.unlock() }
        // Stop discover timer.
        discoverTimer?.cancel()
        discoverTimer = nil
        // Send publisher completion.
        discoverSubject?.send(completion: .finished)
        discoverSubject = nil
    }
    
}

// MARK: - Peripherals retrieval

extension BleCentralManagerProxy {
    
    /// Retrieves all peripherals that are connected to the system and implement any of the services listed in serviceUUIDs.
    ///
    /// This method returns peripherals that are currently connected to the system and offer specific services.
    ///
    /// - Parameter serviceUUIDs: A list of service UUIDs (represented by `CBUUID` objects) to filter connected peripherals.
    /// - Returns: A list of objects implementing the `BlePeripheral` protocol.
    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [BlePeripheral] {
        return centralManager.retrieveConnectedPeripherals(withServiceIds: serviceUUIDs)
    }
    
    /// Retrieve all the peripherals with the corresponding identifiers.
    ///
    /// This method retrieves previously connected peripherals with specific identifiers.
    ///
    /// - Parameter identifiers: A list of peripheral identifiers (represented by `UUID` objects) from which peripheral objects can be retrieved.
    /// - Returns: A list of objects implementing the `BlePeripheral` protocol.
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [BlePeripheral] {
        return centralManager.retrievePeripherals(withIds: identifiers)
    }
    
}

// MARK: - State change

extension BleCentralManagerProxy {
    
    /// Waits until the central manager is in the `.poweredOn` state, executing the callback upon success or failure.
    ///
    /// This method registers a callback that is invoked when the central manager's state changes to `.poweredOn`, or an error occurs.
    /// The method also verifies that the central manager is authorized and supported.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// bleCentralManagerProxy.waitUntilReady(timeout: .seconds(10)) { result in
    ///     switch result {
    ///         case .success:
    ///             print("Central manager is ready")
    ///         case .failure(let error):
    ///             print("Central manager is not ready: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - timeout: The maximum time to wait for the central manager to become ready. Default is `.never`.
    ///   - callback: A closure that receives a `Result` indicating success or an error if the central manager is unauthorized or unsupported.
    ///
    /// - Note: If the state is already `.poweredOn`, the callback is called immediately with success.
    public func waitUntilReady(timeout: DispatchTimeInterval = .never, callback: @escaping ((Result<Void, Error>) -> Void)) {
                
        lock.lock()
        defer { lock.unlock() }
                
        // Ensure central manager is not already powered on.
        guard centralManager.state != .poweredOn else {
            callback(.success(()))
            return
        }
        
        // Ensure central manager is authorized.
        guard centralManager.state != .unauthorized else {
            callback(.failure(BleCentralManagerProxyError.invalidState(.unauthorized)))
            return
        }
        
        // Ensure central manager is supported.
        guard centralManager.state != .unsupported else {
            callback(.failure(BleCentralManagerProxyError.invalidState(.unsupported)))
            return
        }
        
        // Register a callback to be notified when central manager is powered on.
        waitUntilReadyRegistry.register(callback: callback, timeout: timeout) {
            $0.notify(.failure(BleCentralManagerProxyError.readyTimeout))
        }
        
    }
    
}

// MARK: - Timers

extension BleCentralManagerProxy {
    
    func startDiscoverTimer(timeout: DispatchTimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        guard timeout != .never else {
            discoverTimer?.cancel()
            discoverTimer = nil
            return
        }
        discoverTimer?.cancel()
        discoverTimer = DispatchSource.makeTimerSource(queue: globalQueue)
        discoverTimer?.schedule(deadline: .now() + timeout, repeating: .never)
        discoverTimer?.setEventHandler { [weak self] in
            guard let self else { return }
            lock.lock()
            defer { lock.unlock() }
            // Stop scanning for peripherals.
            centralManager.stopScan()
            // Kill the timer and reset.
            discoverTimer?.cancel()
            discoverTimer = nil
            // Send out completion on the publisher.
            discoverSubject?.send(completion: .finished)
            discoverSubject = nil
        }
        discoverTimer?.resume()
    }

}
