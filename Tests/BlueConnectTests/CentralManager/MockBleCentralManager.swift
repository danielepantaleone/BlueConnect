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

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

@testable import BlueConnect

class MockBleCentralManager: BleCentralManager, @unchecked Sendable {
    
    // MARK: - Atomic properties
    
    var _state: CBManagerState = .poweredOff {
        didSet {
            queue.async { [weak self] in
                guard let self else { return }
                let localDelegate: BleCentralManagerDelegate?
                lock.lock()
                localDelegate = centraManagerDelegate
                disconnectAllPeripheralsIfNotPoweredOn()
                lock.unlock()
                localDelegate?.bleCentralManagerDidUpdateState(self)
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
        
    private let lock = NSRecursiveLock()
    private let queue: DispatchQueue = DispatchQueue(label: "com.blueconnect.central-manager", qos: .userInitiated)
    private let peripherals: [BlePeripheral]
    private var scanTimer: DispatchSourceTimer?
    private var scanCounter: Int = 0

    // MARK: - Initialization
    
    init(peripherals: [BlePeripheral]) {
        self.peripherals = peripherals
    }
    
    // MARK: - Interface
    
    func connect(_ peripheral: BlePeripheral, options: [String: Any]?) {
        
        guard peripheral.state != .connecting else { return }
        guard let localPeripheral = peripheral as? MockBlePeripheral else { return }
        localPeripheral.state = .connecting // move to connecting state before going async
        
        queue.async { [weak self, weak localPeripheral] in
            
            guard let self else { return }
            guard let localPeripheral else { return }
            
            let localDelegate: BleCentralManagerDelegate?
            let localDelay: DispatchTimeInterval?
            let localError: Error?
            lock.lock()
            localDelegate = centraManagerDelegate
            if state != .poweredOn {
                localDelay = nil
                localError = MockBleError.bluetoothIsOff
                localPeripheral.state = .disconnected
            } else if let errorOnConnection {
                localDelay = nil
                localError = errorOnConnection
                localPeripheral.state = .disconnected
            } else {
                localDelay = delayOnConnection
                localError = nil
            }
            self.delayOnConnection = nil
            self.errorOnConnection = nil
            lock.unlock()
            
            if let localError {
                localDelegate?.bleCentralManager(self, didFailToConnect: localPeripheral, error: localError)
            } else {
                
                @Sendable
                func _connectInternal(_ localPeripheral: MockBlePeripheral) {
                    let localDelegate: BleCentralManagerDelegate?
                    lock.lock()
                    guard state == .poweredOn, localPeripheral.state == .connecting else {
                        lock.unlock()
                        return
                    }
                    localDelegate = centraManagerDelegate
                    localPeripheral.state = .connected
                    lock.unlock()
                    localDelegate?.bleCentralManager(self, didConnect: localPeripheral)
                }
                
                if let localDelay {
                    queue.asyncAfter(deadline: .now() + localDelay) { [weak localPeripheral] in
                        guard let localPeripheral else { return }
                        _connectInternal(localPeripheral)
                    }
                } else {
                    _connectInternal(localPeripheral)
                }
                
            }

        }

    }
    
    func cancelConnection(_ peripheral: BlePeripheral) {
        
        guard peripheral.state != .disconnecting else { return }
        guard let localPeripheral = peripheral as? MockBlePeripheral else { return }
        localPeripheral.state = .disconnecting
        
        queue.async { [weak self, weak localPeripheral] in
            
            guard let self else { return }
            guard let localPeripheral else { return }
            
            let localDelegate: BleCentralManagerDelegate?
            let localDelay: DispatchTimeInterval?
            let localError: Error?
            lock.lock()
            localDelegate = centraManagerDelegate
            if state != .poweredOn {
                localDelay = nil
                localError = MockBleError.bluetoothIsOff
            } else if let errorOnDisconnection {
                localDelay = nil
                localError = errorOnDisconnection
            } else {
                localDelay = delayOnDisconnection
                localError = nil
            }
            self.delayOnDisconnection = nil
            self.errorOnDisconnection = nil
            lock.unlock()
            
            if let localError {
                localDelegate?.bleCentralManager(self, didDisconnectPeripheral: localPeripheral, error: localError)
            } else {
                
                @Sendable
                func _disconnectInternal(_ mockPeripheral: MockBlePeripheral) {
                    let localDelegate: BleCentralManagerDelegate?
                    lock.lock()
                    guard state == .poweredOn, localPeripheral.state != .disconnected else {
                        lock.unlock()
                        return
                    }
                    localDelegate = centraManagerDelegate
                    localPeripheral.state = .disconnected
                    lock.unlock()
                    localDelegate?.bleCentralManager(self, didDisconnectPeripheral: localPeripheral, error: nil)
                }
                
                if let localDelay {
                    queue.asyncAfter(deadline: .now() + localDelay) { [weak localPeripheral] in
                        guard let localPeripheral else { return }
                        _disconnectInternal(localPeripheral)
                    }
                } else {
                    _disconnectInternal(localPeripheral)
                }
                
            }
            
        }
        
    }
    
    func retrievePeripherals(withIds identifiers: [UUID]) -> [BlePeripheral] {
        lock.lock()
        defer { lock.unlock() }
        return peripherals.filter { peripheral in
            identifiers.contains { $0 == peripheral.identifier }
        }
    }
    
    func retrieveConnectedPeripherals(withServiceIds serviceUUIDs: [CBUUID]) -> [BlePeripheral] {
        lock.lock()
        defer { lock.unlock() }
        return peripherals.filter { peripheral in
            guard peripheral.state == .connected else { return false }
            guard let services = peripheral.services else { return false }
            guard services.map({ $0.uuid }).contains(oneOf: serviceUUIDs) else { return false}
            return true
        }
    }
    
    func scanForPeripherals(withServices: [CBUUID]?, options: [String: Any]?) {
        lock.lock()
        defer { lock.unlock() }
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
    
    func stopScan() {
        lock.lock()
        defer { lock.unlock() }
        scanTimer?.cancel()
        scanTimer = nil
        isScanning = false
        scanCounter = 0
    }
    
    // MARK: - Internals
    
    private func disconnectAllPeripheralsIfNotPoweredOn() {
        guard state != .poweredOn else { return }
        for peripheral in peripherals {
            guard let mockPeripheral = peripheral as? MockBlePeripheral else { continue }
            mockPeripheral.state = .disconnected
        }
    }
    
    private func scanInterval() {
        let localDelegate: BleCentralManagerDelegate?
        let localPeripheral: BlePeripheral
        lock.lock()
        guard !peripherals.isEmpty, let scanTimer, !scanTimer.isCancelled else {
            lock.unlock()
            return
        }
        localDelegate = centraManagerDelegate
        localPeripheral = peripherals[scanCounter % peripherals.count]
        scanCounter += 1
        lock.unlock()
        
        var advertisementData: [String: Any] = [:]
        advertisementData[CBAdvertisementDataIsConnectable] = true
        if let name = localPeripheral.name {
            advertisementData[CBAdvertisementDataLocalNameKey] = name
        }
        localDelegate?.bleCentralManager(
            self,
            didDiscover: localPeripheral,
            advertisementData: .init(advertisementData),
            rssi: Int.random(in: (-90)...(-50)))
    
    }
    
}
