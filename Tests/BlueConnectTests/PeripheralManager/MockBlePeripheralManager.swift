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

class MockBlePeripheralManager: BlePeripheralManager, @unchecked Sendable {
    
    // MARK: - Atomic properties
    
    var _state: CBManagerState = .poweredOff {
        didSet {
            queue.async { [weak self] in
                guard let self else { return }
                let localDelegate: BlePeripheralManagerDelegate?
                lock.lock()
                localDelegate = peripheralManagerDelegate
                lock.unlock()
                localDelegate?.blePeripheralManagerDidUpdateState(self)
            }
        }
    }
    
    // MARK: - Properties
    
    var errorOnUpdateValue: Bool = false
    var errorOnAdvertising: Error?
    var delayOnAdvertising: DispatchTimeInterval?
        
    // MARK: - Protocol properties
    
    var authorization: CBManagerAuthorization { .allowedAlways }
    var isAdvertising: Bool = false
    var state: CBManagerState {
        get { lock.withLock { _state } }
        set { lock.withLock { _state = newValue } }
    }
    
    weak var peripheralManagerDelegate: BlePeripheralManagerDelegate?
    
    // MARK: - Internal properties
    
    let lock = NSRecursiveLock()
    let queue: DispatchQueue = DispatchQueue(label: "com.blueconnect.peripheral-manager", qos: .userInitiated)
    var services: [CBMutableService] = []
        
    // MARK: - Interface
    
    func startAdvertising(_ advertisementData: [String: Any]?) {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            let localDelegate: BlePeripheralManagerDelegate?
            let localDelay: DispatchTimeInterval?
            let localError: Error?
            lock.lock()
            guard !isAdvertising else {
                lock.unlock()
                return
            }
            localDelegate = peripheralManagerDelegate
            if state != .poweredOn {
                localDelay = nil
                localError = MockBleError.bluetoothIsOff
            } else if let errorOnAdvertising {
                localDelay = nil
                localError = errorOnAdvertising
            } else {
                localDelay = delayOnAdvertising
                localError = nil
            }
            self.delayOnAdvertising = nil
            self.errorOnAdvertising = nil
            lock.unlock()
            
            if let localError {
                localDelegate?.blePeripheralManagerDidStartAdvertising(self, error: localError)
            } else {
                
                @Sendable
                func _advertiseInternal() {
                    let localDelegate: BlePeripheralManagerDelegate?
                    lock.lock()
                    guard state == .poweredOn, !isAdvertising else {
                        lock.unlock()
                        return
                    }
                    localDelegate = peripheralManagerDelegate
                    isAdvertising = true
                    lock.unlock()
                    localDelegate?.blePeripheralManagerDidStartAdvertising(self, error: nil)
                }
                
                if let localDelay {
                    queue.asyncAfter(deadline: .now() + localDelay) {
                        _advertiseInternal()
                    }
                } else {
                    _advertiseInternal()
                }
                
            }
          
        }
        
    }
    
    func stopAdvertising() {
        lock.lock()
        defer { lock.unlock() }
        isAdvertising = false
    }
    
    func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: any BlueConnect.BleCentral) {
        
    }
    
    func add(_ service: CBMutableService) {
        lock.lock()
        defer { lock.unlock() }
        services.append(service)
    }
    
    func remove(_ service: CBMutableService) {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll { $0.uuid == service.uuid }
    }
    
    func removeAllServices() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
    }
    
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        
    }
    
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [BleCentral]?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !errorOnUpdateValue
    }
    
}
