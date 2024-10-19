//
//  BleCentralManagerProxy+BleCentralManagerDelegate.swift
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

extension BleCentralManagerProxy: BleCentralManagerDelegate {
    
    public func bleCentralManagerDidUpdateState(_ central: BleCentralManager) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Kill peripheral discovery and notify connection failures and disconnections.
        if central.state != .poweredOn {
            
            // Stop discover timer.
            stopDiscoverTimer()
            // Send publisher failure.
            discoverSubject?.send(completion: .failure(BleCentralManagerProxyError.invalidState(central.state)))
            discoverSubject = nil
            
            // Notify connection failures.
            for (peripheralIdentifier, state) in connectionState where state == .connecting {
                guard let peripheral = centralManager.retrievePeripherals(withIds: [peripheralIdentifier]).first else { continue }
                // Track disconnected state.
                connectionState[peripheral.identifier] = .disconnected
                // Stop timer.
                stopConnectionTimer(peripheralIdentifier: peripheral.identifier)
                // Notify publisher.
                didFailToConnectSubject.send((peripheral, BleCentralManagerProxyError.invalidState(central.state)))
                // Notify registered callbacks.
                notifyCallbacks(
                    store: &connectionCallbacks,
                    uuid: peripheral.identifier,
                    value: .failure(BleCentralManagerProxyError.invalidState(central.state)))
            }
            
            // Notify disconnect.
            for (peripheralIdentifier, state) in connectionState where state == .connected {
                guard let peripheral = centralManager.retrievePeripherals(withIds: [peripheralIdentifier]).first else { continue }
                // Track disconnected state.
                connectionState[peripheral.identifier] = .disconnected
                // Notify publisher.
                didDisconnectSubject.send((peripheral, BleCentralManagerProxyError.invalidState(central.state)))
                // Notify registered callbacks.
                notifyCallbacks(
                    store: &disconnectionCallbacks,
                    uuid: peripheral.identifier,
                    value: .failure(BleCentralManagerProxyError.invalidState(central.state)))
            }
            
            // Remove any tracked connection timeout.
            connectionTimeouts.removeAll()
            
        }
        
        // Notify state publisher.
        didUpdateStateSubject.send(central.state)
        
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didConnect peripheral: BlePeripheral) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .connected
        // Stop timer.
        stopConnectionTimer(peripheralIdentifier: peripheral.identifier)
        // Notify publisher.
        didConnectSubject.send(peripheral)
        // Notify registered callbacks.
        notifyCallbacks(
            store: &connectionCallbacks,
            uuid: peripheral.identifier,
            value: .success(()))
        
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didDisconnectPeripheral peripheral: BlePeripheral, error: Error?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Stop the connection timer just in case iOS delivers disconnect instead of connection failure.
        stopConnectionTimer(peripheralIdentifier: peripheral.identifier)
        
        // This is a disconnection caused by canceling a peripheral connection after timeout.
        if connectionTimeouts.contains(peripheral.identifier) {
            // Notify publisher.
            didFailToConnectSubject.send((peripheral, BleCentralManagerProxyError.connectionTimeout))
            // Notify callbacks.
            notifyCallbacks(
                store: &connectionCallbacks,
                uuid: peripheral.identifier,
                value: .failure(BleCentralManagerProxyError.connectionTimeout))
        }
        // Here the peripheral did not connect at all so we route this over the connection failed publisher.
        else if connectionState[peripheral.identifier] == .connecting {
            // Notify publisher.
            didFailToConnectSubject.send((peripheral, error ?? BleCentralManagerProxyError.unknown))
            // Notify callbacks.
            notifyCallbacks(
                store: &connectionCallbacks,
                uuid: peripheral.identifier,
                value: .failure(error ?? BleCentralManagerProxyError.unknown))
        }
        // Regular disconnection.
        else {
            // Notify publisher.
            didDisconnectSubject.send((peripheral, error))
            // Notify registered callbacks.
            notifyCallbacks(
                store: &disconnectionCallbacks,
                uuid: peripheral.identifier,
                value: .success(()))
        }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .disconnected
        connectionTimeouts.remove(peripheral.identifier)

    }
    
    public func bleCentralManager(_ central: BleCentralManager, didDiscover peripheral: BlePeripheral, advertisementData: BleAdvertisementData, rssi RSSI: Int) {
        discoverSubject?.send((
            peripheral: peripheral,
            advertisementData: advertisementData,
            RSSI: RSSI))
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didFailToConnect peripheral: BlePeripheral, error: Error?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .disconnected
        connectionTimeouts.remove(peripheral.identifier)
        // Stop timer
        stopConnectionTimer(peripheralIdentifier: peripheral.identifier)
        // Notify publisher
        didFailToConnectSubject.send((peripheral, error ?? BleCentralManagerProxyError.unknown))
        // Notify registered callbacks
        notifyCallbacks(
            store: &connectionCallbacks,
            uuid: peripheral.identifier,
            value: .failure(error ?? BleCentralManagerProxyError.unknown))
        
    }
    
    public func bleCentralManager(_ central: BleCentralManager, willRestoreState dict: [String: Any]) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Track connection state.
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                connectionState[peripheral.identifier] = peripheral.state
            }
        }
        
        // Notify publisher.
        willRestoreStateSubject.send(dict)
        
    }
    
}
