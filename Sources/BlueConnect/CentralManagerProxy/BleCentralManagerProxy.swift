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
#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

/// `BleCentralManagerProxy` provides a higher-level abstraction for managing BLE peripherals via `BleCentralManager`.
///
/// This class uses Combine publishers to emit updates on BLE-related events, such as peripheral discovery, peripheral connection/disconnection and state updates.
public class BleCentralManagerProxy: NSObject, @unchecked Sendable {
    
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
    var connectionCanceled: Set<UUID> = []
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
