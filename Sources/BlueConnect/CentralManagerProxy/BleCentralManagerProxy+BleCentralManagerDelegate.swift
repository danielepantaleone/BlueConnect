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

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

extension BleCentralManagerProxy: BleCentralManagerDelegate {
    
    public func bleCentralManagerDidUpdateState(_ central: BleCentralManager) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Kill peripheral discovery and notify connection failures and disconnections.
        if central.state != .poweredOn {
            
            // Stop discover timer.
            discoverTimer?.cancel()
            discoverTimer = nil

            // Send publisher failure.
            discoverSubject?.send(completion: .failure(BleCentralManagerProxyError.invalidState(central.state)))
            discoverSubject = nil
            
            // Notify connection failures.
            for (peripheralIdentifier, state) in connectionState {
                
                // Retrieve the peripheral matching the tracked identifier.
                guard let peripheral = centralManager.retrievePeripherals(withIds: [peripheralIdentifier]).first else {
                    continue
                }
                
                // Track disconnected state.
                connectionState[peripheral.identifier] = .disconnected
                
                if state == .connecting {
                    // Notify publisher.
                    didFailToConnectSubject.send((peripheral, BleCentralManagerProxyError.invalidState(central.state)))
                    // Notify registered callbacks.
                    connectionRegistry.notify(key: peripheral.identifier, value: .failure(BleCentralManagerProxyError.invalidState(central.state)))
                } else if state == .connected {
                    // Notify publisher.
                    didDisconnectSubject.send((peripheral, BleCentralManagerProxyError.invalidState(central.state)))
                    // Notify registered callbacks.
                    disconnectionRegistry.notify(key: peripheral.identifier, value: .failure(BleCentralManagerProxyError.invalidState(central.state)))
                }
                
            }
            
            // Remove any tracked connection data.
            connectionTimeouts.removeAll()
            connectionCanceled.removeAll()
            
            // If we go unauthorized or unsupported stop waiting for central to be ready.
            if central.state == .unauthorized {
                waitUntilReadyRegistry.notifyAll(.failure(BleCentralManagerProxyError.invalidState(.unauthorized)))
            } else if central.state == .unsupported {
                waitUntilReadyRegistry.notifyAll(.failure(BleCentralManagerProxyError.invalidState(.unsupported)))
            }
            
        } else {
            
            // Notify any registered callback.
            waitUntilReadyRegistry.notifyAll(.success(()))
            
        }
        
        // Notify state publisher.
        didUpdateStateSubject.send(central.state)
        
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didConnect peripheral: BlePeripheral) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .connected
        // Remove connection timeouts and cancel requests for this peripheral.
        connectionTimeouts.remove(peripheral.identifier)
        connectionCanceled.remove(peripheral.identifier)
        // Notify publisher.
        didConnectSubject.send(peripheral)
        // Notify registered callbacks.
        connectionRegistry.notify(key: peripheral.identifier, value: .success(()))
      
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didDisconnectPeripheral peripheral: BlePeripheral, error: Error?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        let isConnecting = connectionState[peripheral.identifier] == .connecting
        let isTimeout = connectionTimeouts.contains(peripheral.identifier)
        let isCanceled = connectionCanceled.contains(peripheral.identifier)
        
        // Track connection state.
        connectionState[peripheral.identifier] = .disconnected
        connectionTimeouts.remove(peripheral.identifier)
        connectionCanceled.remove(peripheral.identifier)
        
        if isTimeout { // Disconnection caused by canceling a peripheral connection after timeout.
            didFailToConnectSubject.send((peripheral, BleCentralManagerProxyError.connectionTimeout))
        } else if isCanceled { // Did not connect at all so we route this over the connection failed publisher (manual canceling).
            didFailToConnectSubject.send((peripheral, BleCentralManagerProxyError.connectionCanceled))
        } else if isConnecting { // Did not connect at all so we route this over the connection failed publisher (regular failure).
            didFailToConnectSubject.send((peripheral, error ?? BleCentralManagerProxyError.unknown))
        } else { // Regular disconnection.
            didDisconnectSubject.send((peripheral, error))
        }
        
        if isCanceled && !isTimeout { // Did not connect at all and no timeout so we route this over the connection failed publisher (manual canceling).
            connectionRegistry.notify(key: peripheral.identifier, value: .failure(BleCentralManagerProxyError.connectionCanceled))
        } else if isConnecting && !isTimeout { // Did not connect at all and no timeout so we route this over the connection failed publisher (regular failure).
            connectionRegistry.notify(key: peripheral.identifier, value: .failure(error ?? BleCentralManagerProxyError.unknown))
        }
        
        // Always notify disconnection on the callbacks because we may have disconnected a connecting peripheral.
        disconnectionRegistry.notify(key: peripheral.identifier, value: .success(()))

    }
    
    public func bleCentralManager(_ central: BleCentralManager, didDiscover peripheral: BlePeripheral, advertisementData: BleAdvertisementData, rssi RSSI: Int) {
        lock.lock()
        defer { lock.unlock() }
        discoverSubject?.send((
            peripheral: peripheral,
            advertisementData: advertisementData,
            RSSI: RSSI))
    }
    
    public func bleCentralManager(_ central: BleCentralManager, didFailToConnect peripheral: BlePeripheral, error: Error?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .disconnected
        connectionTimeouts.remove(peripheral.identifier)
        connectionCanceled.remove(peripheral.identifier)
        // Notify publisher.
        didFailToConnectSubject.send((peripheral, error ?? BleCentralManagerProxyError.unknown))
        // Notify registered callbacks.
        connectionRegistry.notify(key: peripheral.identifier, value: .failure(error ?? BleCentralManagerProxyError.unknown))
      
    }
    
    public func bleCentralManager(_ central: BleCentralManager, willRestoreState dict: [String: Any]) {
        
        lock.lock()
        defer { lock.unlock() }
        
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
