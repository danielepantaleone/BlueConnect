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

class MockBlePeripheralManager: BlePeripheralManager, @unchecked Sendable {
    
    // MARK: - Properties
    
    var errorOnUpdateValue: Bool = false
    var errorOnAdvertising: Error?
    var delayOnAdvertising: DispatchTimeInterval?
        
    // MARK: - Protocol properties
    
    var authorization: CBManagerAuthorization { .allowedAlways }
    var isAdvertising: Bool = false
    var state: CBManagerState = .poweredOff {
        didSet {
            queue.async { [weak self] in
                guard let self else { return }
                peripheralManagerDelegate?.blePeripheralManagerDidUpdateState(self)
            }
        }
    }
    
    weak var peripheralManagerDelegate: BlePeripheralManagerDelegate?
    
    // MARK: - Internal properties
    
    let mutex = RecursiveMutex()
    var services: [CBMutableService] = []
        
    lazy var queue: DispatchQueue = DispatchQueue.global(qos: .background)
    
    // MARK: - Interface
    
    func startAdvertising(_ advertisementData: [String: Any]?) {
        queue.async { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            guard !isAdvertising else { return }
            guard errorOnAdvertising == nil else {
                peripheralManagerDelegate?.blePeripheralManagerDidStartAdvertising(self, error: errorOnAdvertising)
                errorOnAdvertising = nil
                return
            }
            @Sendable func _advertiseInternal() {
                mutex.lock()
                defer { mutex.unlock() }
                guard state == .poweredOn else { return }
                isAdvertising = true
                peripheralManagerDelegate?.blePeripheralManagerDidStartAdvertising(self, error: nil)
            }
            if let delayOnAdvertising {
                queue.asyncAfter(deadline: .now() + delayOnAdvertising) {
                    _advertiseInternal()
                }
                self.delayOnAdvertising = nil
            } else {
                _advertiseInternal()
            }
        }
    }
    
    func stopAdvertising() {
        mutex.lock()
        defer { mutex.unlock() }
        guard isAdvertising else { return }
        isAdvertising = false
    }
    
    func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: any BlueConnect.BleCentral) {
        
    }
    
    func add(_ service: CBMutableService) {
        mutex.lock()
        defer { mutex.unlock() }
        services.append(service)
    }
    
    func remove(_ service: CBMutableService) {
        mutex.lock()
        defer { mutex.unlock() }
        services.removeAll { $0.uuid == service.uuid }
    }
    
    func removeAllServices() {
        mutex.lock()
        defer { mutex.unlock() }
        services.removeAll()
    }
    
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        
    }
    
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [BleCentral]?) -> Bool {
        return !errorOnUpdateValue
    }
    
}
