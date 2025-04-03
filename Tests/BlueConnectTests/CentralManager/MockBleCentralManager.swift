//
//  MockBleCentralManager.swift
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
import Foundation

@testable import BlueConnect

class MockBleCentralManager: BleCentralManager, @unchecked Sendable {
    
    // MARK: - Atomic properties
    
    var _state: CBManagerState = .poweredOff {
        didSet {
            queue.async { [weak self] in
                guard let self else { return }
                disconnectAllPeripheralsIfNotPoweredOn()
                centraManagerDelegate?.bleCentralManagerDidUpdateState(self)
            }
        }
    }
    
    // MARK: - Properties
    
    var errorOnConnection: Error?
    var errorOnDisconnection: Error?
    var delayOnConnection: DispatchTimeInterval?
    var delayOnDisconnection: DispatchTimeInterval?
    
    // MARK: - Protocol properties
    
    weak var centraManagerDelegate: BleCentralManagerDelegate?

    var authorization: CBManagerAuthorization { .allowedAlways }
    var isScanning: Bool = false
    var state: CBManagerState {
        get { lock.withLock { _state } }
        set { lock.withLock { _state = newValue } }
    }
    
    // MARK: - Internal properties
        
    let lock = NSRecursiveLock()
    let queue: DispatchQueue = DispatchQueue(label: "com.blueconnect.central-manager", qos: .userInitiated)
    var peripherals: [BlePeripheral] = []
    var scanTimer: DispatchSourceTimer?
    var scanCounter: Int = 0

    // MARK: - Initialization
    
    init(peripherals: [BlePeripheral]) {
        self.peripherals = peripherals
    }
    
    // MARK: - Interface
    
    func connect(_ peripheral: BlePeripheral, options: [String: Any]?) {
        guard peripheral.state != .connecting else { return }
        guard let mockPeripheral = peripheral as? MockBlePeripheral else { return }
        // move to connecting state before going async
        mockPeripheral.state = .connecting
        queue.async { [weak self] in
            guard let self else { return }
            lock.withLock {
                guard state == .poweredOn else {
                    mockPeripheral.state = .disconnected
                    centraManagerDelegate?.bleCentralManager(
                        self,
                        didFailToConnect: mockPeripheral,
                        error: MockBleError.bluetoothIsOff)
                    return
                }
                guard errorOnConnection == nil else {
                    mockPeripheral.state = .disconnected
                    centraManagerDelegate?.bleCentralManager(
                        self,
                        didFailToConnect: mockPeripheral,
                        error: errorOnConnection)
                    errorOnConnection = nil
                    return
                }
                @Sendable func _connectInternal() {
                    guard state == .poweredOn else { return }
                    guard mockPeripheral.state == .connecting else { return }
                    mockPeripheral.state = .connected
                    centraManagerDelegate?.bleCentralManager(self, didConnect: mockPeripheral)
                }
                if let delayOnConnection {
                    queue.asyncAfter(deadline: .now() + delayOnConnection) {
                        self.lock.withLock {
                            _connectInternal()
                        }
                    }
                    self.delayOnConnection = nil
                } else {
                    _connectInternal()
                }
            }
        }
    }
    
    func cancelConnection(_ peripheral: BlePeripheral) {
        guard peripheral.state != .disconnecting else { return }
        guard let mockPeripheral = peripheral as? MockBlePeripheral else { return }
        mockPeripheral.state = .disconnecting
        queue.async { [weak self] in
            guard let self else { return }
            lock.withLock {
                let error: Error?
                if state != .poweredOn {
                    error = MockBleError.bluetoothIsOff
                } else if let errorOnDisconnection {
                    error = errorOnDisconnection
                    self.errorOnDisconnection = nil
                } else {
                    error = nil
                }
                @Sendable func _disconnectInternal() {
                    guard mockPeripheral.state == .disconnecting else { return }
                    mockPeripheral.state = .disconnected
                    centraManagerDelegate?.bleCentralManager(
                        self,
                        didDisconnectPeripheral: mockPeripheral,
                        error: error)
                }
                if let delayOnDisconnection {
                    queue.asyncAfter(deadline: .now() + delayOnDisconnection) {
                        self.lock.withLock {
                            _disconnectInternal()
                        }
                    }
                    self.delayOnDisconnection = nil
                } else {
                    _disconnectInternal()
                }
            }
        }
    }
    
    func retrievePeripherals(withIds identifiers: [UUID]) -> [BlePeripheral] {
        lock.withLock {
            peripherals.filter { peripheral in
                identifiers.contains { $0 == peripheral.identifier }
            }
        }
    }
    
    func retrieveConnectedPeripherals(withServiceIds serviceUUIDs: [CBUUID]) -> [BlePeripheral] {
        lock.withLock {
            peripherals.filter { peripheral in
                guard peripheral.state == .connected else { return false }
                guard let services = peripheral.services else { return false }
                guard services.map({ $0.uuid }).contains(oneOf: serviceUUIDs) else { return false}
                return true
            }
        }
    }
    
    func scanForPeripherals(withServices: [CBUUID]?, options: [String: Any]?) {
        lock.withLock {
            isScanning = true
            scanCounter = 0
            scanTimer?.cancel()
            scanTimer = DispatchSource.makeTimerSource(queue: queue)
            scanTimer?.schedule(deadline: .now() + .seconds(1), repeating: 1.0)
            scanTimer?.setEventHandler { [weak self] in
                self?.scanInterval()
            }
            scanTimer?.resume()
        }
    }
    
    func stopScan() {
        lock.withLock {
            scanTimer?.cancel()
            scanTimer = nil
            isScanning = false
            scanCounter = 0
        }
    }
    
    // MARK: - Internals
    
    private func disconnectAllPeripheralsIfNotPoweredOn() {
        lock.withLock {
            guard state != .poweredOn else { return }
            for peripheral in peripherals {
                guard let mockPeripheral = peripheral as? MockBlePeripheral else { continue }
                mockPeripheral.state = .disconnected
            }
        }
    }
    
    private func scanInterval() {
        lock.withLock {
            guard !peripherals.isEmpty else { return }
            guard let scanTimer, !scanTimer.isCancelled else { return }
            scanCounter += 1
            let peripheral = peripherals[scanCounter % peripherals.count]
            guard let mockPeripheral = peripheral as? MockBlePeripheral else { return }
            queue.async { [weak self] in
                guard let self else { return }
                var advertisementData: [String: Any] = [:]
                advertisementData[CBAdvertisementDataIsConnectable] = true
                if let name = mockPeripheral.name {
                    advertisementData[CBAdvertisementDataLocalNameKey] = name
                }
                centraManagerDelegate?.bleCentralManager( // FIX ADD QUEUE
                    self,
                    didDiscover: mockPeripheral,
                    advertisementData: .init(advertisementData),
                    rssi: Int.random(in: (-90)...(-50)))
            }
        }
    }
    
}
