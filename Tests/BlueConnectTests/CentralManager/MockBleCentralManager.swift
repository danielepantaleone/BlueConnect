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

import CoreBluetooth
import Foundation

@testable import BlueConnect

class MockBleCentralManager: BleCentralManager {
    
    // MARK: - Properties
    
    var errorOnConnection: Error?
    var errorOnDisconnection: Error?
    var delayOnConnection: DispatchTimeInterval?
    var delayOnDisconnection: DispatchTimeInterval?
    var timeoutOnConnection: Bool = false

    // MARK: - Private properties
    
    private var discoveredPeripherals: [BlePeripheral] = []

    // MARK: - Protocol properties
    
    var authorization: CBManagerAuthorization { .allowedAlways }
    var centraManagerDelegate: BleCentralManagerDelegate?
    let isScanning: Bool = false
    let mutex = RecursiveMutex()
    var state: CBManagerState = .poweredOff {
        didSet {
            queue.async { [weak self] in
                guard let self else { return }
                centraManagerDelegate?.bleCentralManagerDidUpdateState(self)
                disconnectAllPeripheralsIfNotPoweredOn()
            }
        }
    }
    
    // MARK: - Private properties
    
    lazy var queue: DispatchQueue = DispatchQueue.global(qos: .background)

    // MARK: - Interface
    
    func connect(_ peripheral: BlePeripheral, options: [String: Any]?) {
        guard let mockPeripheral = peripheral as? MockBlePeripheral else {
            return
        }
        // move to connecting state before going async
        mockPeripheral.state = .connecting
        queue.async { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            guard state == .poweredOn else {
                mockPeripheral.state = .disconnected
                centraManagerDelegate?.bleCentralManager(
                    self,
                    didFailToConnect: peripheral,
                    error: MockBleError.bluetoothIsOff)
                return
            }
            guard !timeoutOnConnection else {
                // Keep the peripheral in connecting state to simulate iOS behaviour
                timeoutOnConnection = false
                return
            }
            guard errorOnConnection == nil else {
                mockPeripheral.state = .disconnected
                centraManagerDelegate?.bleCentralManager(
                    self,
                    didFailToConnect: peripheral,
                    error: errorOnConnection)
                errorOnConnection = nil
                return
            }
            func _connectInternal() {
                mutex.lock()
                defer { mutex.unlock() }
                guard mockPeripheral.state == .connecting else { return }
                mockPeripheral.state = .connected
                centraManagerDelegate?.bleCentralManager(self, didConnect: mockPeripheral)
            }
            if let delayOnConnection {
                queue.asyncAfter(deadline: .now() + delayOnConnection) {
                    _connectInternal()
                }
                self.delayOnConnection = nil
            } else {
                _connectInternal()
            }
        }
    }
    
    func cancelConnection(_ peripheral: BlePeripheral) {
        guard let mockPeripheral = peripheral as? MockBlePeripheral else {
            return
        }
        mockPeripheral.state = .disconnecting
        queue.async { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            guard state == .poweredOn else {
                centraManagerDelegate?.bleCentralManager(
                    self,
                    didFailToConnect: peripheral,
                    error: MockBleError.bluetoothIsOff)
                errorOnDisconnection = nil
                return
            }
            guard errorOnDisconnection == nil else {
                centraManagerDelegate?.bleCentralManager(
                    self,
                    didDisconnectPeripheral: peripheral,
                    error: errorOnDisconnection)
                errorOnDisconnection = nil
                return
            }
            func _disconnectInternal() {
                mutex.lock()
                defer { mutex.unlock() }
                guard mockPeripheral.state == .disconnecting else { return }
                mockPeripheral.state = .disconnected
                centraManagerDelegate?.bleCentralManager(
                    self,
                    didDisconnectPeripheral: mockPeripheral,
                    error: nil)
            }
            if let delayOnDisconnection {
                queue.asyncAfter(deadline: .now() + delayOnDisconnection) {
                    _disconnectInternal()
                }
                self.delayOnDisconnection = nil
            } else {
                _disconnectInternal()
            }
        }
    }
    
    func retrievePeripherals(withIds identifiers: [UUID]) -> [BlePeripheral] {
        mutex.lock()
        defer { mutex.unlock() }
        return discoveredPeripherals.filter { peripheral in
            identifiers.contains { $0 == peripheral.identifier }
        }
    }
    
    func retrieveConnectedPeripherals(withServiceIds serviceUUIDs: [CBUUID]) -> [BlePeripheral] {
        mutex.lock()
        defer { mutex.unlock() }
        return discoveredPeripherals.filter { peripheral in
            guard peripheral.state == .connected else { return false }
            guard let services = peripheral.services else { return false }
            guard services.map({ $0.uuid }).contains(oneOf: serviceUUIDs) else { return false}
            return true
        }
    }
    
    func scanForPeripherals(withServices: [CBUUID]?, options: [String: Any]?) {

    }
    
    func stopScan() {
        
    }
    
    // MARK: - Configuration
    
    func discoveredPeripherals(_ peripherals: [BlePeripheral]) {
        mutex.lock()
        defer { mutex.unlock() }
        discoveredPeripherals.removeAll()
        discoveredPeripherals.append(contentsOf: peripherals)
    }
    
    // MARK: - Internals
    
    private func disconnectAllPeripheralsIfNotPoweredOn() {
        mutex.lock()
        defer { mutex.unlock() }
        guard state != .poweredOn else { return }
        for peripheral in discoveredPeripherals {
            guard let mockPeripheral = peripheral as? MockBlePeripheral else { continue }
            guard mockPeripheral.state != .disconnected else { continue }
            mockPeripheral.state = .disconnected
            centraManagerDelegate?.bleCentralManager(
                self,
                didDisconnectPeripheral: mockPeripheral,
                error: nil)
        }
    }
    
}
