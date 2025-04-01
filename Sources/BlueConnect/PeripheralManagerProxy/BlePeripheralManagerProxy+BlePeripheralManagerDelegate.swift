//
//  BlePeripheralManagerProxy+BlePeripheralManagerDelegate.swift
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

extension BlePeripheralManagerProxy: BlePeripheralManagerDelegate {
    
    public func blePeripheralManagerDidUpdateState(_ peripheral: BlePeripheralManager) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify any registered callback.
        if peripheral.state == .poweredOn {
            waitUntilReadyRegistry.notifyAll(.success(()))
        } else if peripheral.state == .unauthorized {
            waitUntilReadyRegistry.notifyAll(.failure(BlePeripheralManagerProxyError.invalidState(.unauthorized)))
        } else if peripheral.state == .unsupported {
            waitUntilReadyRegistry.notifyAll(.failure(BlePeripheralManagerProxyError.invalidState(.unsupported)))
        }
        
        // Notify state publisher.
        didUpdateStateSubject.send(peripheral.state)
        
    }
    
    public func blePeripheralManagerDidStartAdvertising(_ peripheral: BlePeripheralManager, error: Error?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        if let error {
            
            // Notify any registered callback.
            startAdvertisingRegistry.notifyAll(.failure(error))
            
        } else {
            
            // Notify any registered callback.
            startAdvertisingRegistry.notifyAll(.success(()))
            // Notify state on the publisher.
            didUpdateAdvertisingSubject.send(isAdvertising)
            
            // Start a monitor to check whether advertising is stopped.
            advertisingMonitor?.cancel()
            advertisingMonitor = DispatchSource.makeTimerSource()
            advertisingMonitor?.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
            advertisingMonitor?.setEventHandler { [weak self] in
                guard let self else { return }
                lock.lock()
                defer { lock.unlock() }
                guard !isAdvertising else { return }
                // Kill the timer and reset.
                advertisingMonitor?.cancel()
                advertisingMonitor = nil
                // Notify any registered callback.
                stopAdvertisingRegistry.notifyAll(.success(()))
                // Notify state on the publisher.
                didUpdateAdvertisingSubject.send(isAdvertising)
            }
            advertisingMonitor?.resume()
           
        }
        
    }
    
    public func blePeripheralManagerIsReady(toUpdateSubscribers peripheral: BlePeripheralManager) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify state publisher.
        isReadyToUpdateSubscribersSubject.send(())
        
    }
    
    public func blePeripheralManager(_ peripheral: BlePeripheralManager, didAdd service: CBService, error: Error?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify state publisher.
        didAddServiceSubject.send((service, error))
        
    }
    
    public func blePeripheralManager(_ peripheral: BlePeripheralManager, central: BleCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify state publisher.
        didSubscribeToCharacteristicSubject.send(characteristic)
        
    }
    
    public func blePeripheralManager(_ peripheral: BlePeripheralManager, central: BleCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify state publisher.
        didUnsubscribeFromCharacteristicSubject.send(characteristic)
        
    }
    
    public func blePeripheralManager(_ peripheral: BlePeripheralManager, didReceiveRead request: CBATTRequest) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify state publisher.
        didReceiveReadRequestSubject.send(request)
        
    }
    
    public func blePeripheralManager(_ peripheral: BlePeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify state publisher.
        didReceiveWriteRequestsSubject.send(requests)
        
    }
    
    public func blePeripheralManager(_ peripheral: BlePeripheralManager, willRestoreState dict: [String: Any]) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify publisher.
        willRestoreStateSubject.send(dict)
        
    }
    
}
