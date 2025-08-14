//
//  MockBlePeripheral.swift
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

class MockBlePeripheral: BlePeripheral, @unchecked Sendable {
    
    // MARK: - Atomic properties
    
    var _state: CBPeripheralState = .disconnected {
        didSet {
            if state == .connected {
                startNotify()
            } else {
                stopNotify()
            }
        }
    }
    
    // MARK: - Protocol properties
    
    let identifier: UUID
    var name: String?
    var services: [CBService]? = nil
    var state: CBPeripheralState {
        get { lock.withLock { _state } }
        set { lock.withLock { _state = newValue } }
    }
    
    weak var peripheralDelegate: BlePeripheralDelegate?
    
    // MARK: - Properties
    
    var rssi: Int = -80
    var rssiNotAvailable: Bool = false
    var heartRateProvider: () -> Int = { 90 }
    var errorOnDiscoverServices: Error?
    var errorOnDiscoverCharacteristics: Error?
    var errorOnRead: Error?
    var errorOnWrite: Error?
    var errorOnNotify: Error?
    var errorOnRSSI: Error?
    var delayOnDiscoverServices: DispatchTimeInterval?
    var delayOnDiscoverCharacteristics: DispatchTimeInterval?
    var delayOnRead: DispatchTimeInterval?
    var delayOnWrite: DispatchTimeInterval?
    var delayOnNotify: DispatchTimeInterval?
    var delayOnRSSI: DispatchTimeInterval?
    
    // MARK: - Private properties
    
    private let serialNumber: String
    private let batteryLevel: Int
    private let firmwareRevision: String
    private let hardwareRevision: String
    private let secret: String
    private let lock = NSRecursiveLock()
    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue = DispatchQueue(label: "com.blueconnect.peripheral", qos: .userInitiated)
    
    // MARK: - Services
    
    private let deviceInformationService = CBMutableService(type: MockBleDescriptor.deviceInformationServiceUUID, primary: false)
    private let batteryService = CBMutableService(type: MockBleDescriptor.batteryServiceUUID, primary: false)
    private let heartRateService = CBMutableService(type: MockBleDescriptor.heartRateServiceUUID, primary: false)
    private let customService = CBMutableService(type: MockBleDescriptor.customServiceUUID, primary: false)
    
    // MARK: - Initialization
    
    init(identifier: UUID,
         name: String?,
         serialNumber: String,
         batteryLevel: Int,
         firmwareRevision: String,
         hardwareRevision: String,
         secret: String) {
        self.identifier = identifier
        self.name = name
        self.serialNumber = serialNumber
        self.batteryLevel = batteryLevel
        self.firmwareRevision = firmwareRevision
        self.hardwareRevision = hardwareRevision
        self.secret = secret
    }
    
    // MARK: - Interface
    
    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            lock.lock()
            let localDelegate: BlePeripheralDelegate? = peripheralDelegate
            let localDelay: DispatchTimeInterval?
            let localError: Error?
            if state != .connected {
                localDelay = nil
                localError = MockBleError.peripheralNotConnected
            } else if let errorOnDiscoverServices {
                localDelay = nil
                localError = errorOnDiscoverServices
            } else {
                localDelay = delayOnDiscoverServices
                localError = nil
            }
            lock.unlock()
            
            if let localError {
                localDelegate?.blePeripheral(self, didDiscoverServices: localError)
            } else {
                
                @Sendable
                func _discoverServicesInternal(_ serviceUUIDs: [CBUUID]?) {
                    let localDelegate: BlePeripheralDelegate?
                    let localServices: [CBService]
                    lock.lock()
                    localServices = [deviceInformationService, batteryService, heartRateService, customService]
                    localDelegate = peripheralDelegate
                    services = services.emptyIfNil
                    if let serviceUUIDs {
                        for service in localServices {
                            guard serviceUUIDs.contains(where: { $0 == service.uuid }) else { continue }
                            guard !services!.contains(service) else { continue }
                            services!.append(service)
                        }
                    } else {
                        for service in localServices {
                            guard !services!.contains(service) else { continue }
                            services!.append(service)
                        }
                    }
                    lock.unlock()
                    localDelegate?.blePeripheral(self, didDiscoverServices: nil)
                }
                
                if let localDelay {
                    self.queue.asyncAfter(deadline: .now() + localDelay) {
                        _discoverServicesInternal(serviceUUIDs)
                    }
                    self.delayOnDiscoverServices = nil
                } else {
                    _discoverServicesInternal(serviceUUIDs)
                }
                
            }
            
        }
        
    }
    
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            lock.lock()
            let localDelegate: BlePeripheralDelegate? = peripheralDelegate
            let localDelay: DispatchTimeInterval?
            let localError: Error?
            if state != .connected {
                localDelay = nil
                localError = MockBleError.peripheralNotConnected
            } else if let errorOnDiscoverCharacteristics {
                localDelay = nil
                localError = errorOnDiscoverCharacteristics
            } else {
                localDelay = delayOnDiscoverCharacteristics
                localError = nil
            }
            lock.unlock()
            
            if let localError {
                localDelegate?.blePeripheral(self, didDiscoverCharacteristicsFor: service, error: localError)
            } else {
                
                @Sendable
                func _discoverCharacteristicsInternal(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
                    if service == self.deviceInformationService {
                        self.discoverDeviceInformationServiceCharacteristics(characteristicUUIDs)
                    } else if service == self.batteryService {
                        self.discoverBatteryServiceCharacteristics(characteristicUUIDs)
                    } else if service == self.heartRateService {
                        self.discoverHeartRateServiceCharacteristics(characteristicUUIDs)
                    } else if service == self.customService {
                        self.discoverCustomServiceCharacteristics(characteristicUUIDs)
                    }
                }
                
                if let localDelay {
                    queue.asyncAfter(deadline: .now() + localDelay) {
                        _discoverCharacteristicsInternal(characteristicUUIDs, for: service)
                    }
                } else {
                    _discoverCharacteristicsInternal(characteristicUUIDs, for: service)
                }
                
            }
            
        }
        
    }
    
    func readValue(for characteristic: CBCharacteristic) {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            lock.lock()
            let localDelegate: BlePeripheralDelegate? = peripheralDelegate
            let localError: Error?
            let localDelay: DispatchTimeInterval?
            let localCharacteristic: MockCBCharacteristic?
            if state != .connected {
                localCharacteristic = nil
                localDelay = nil
                localError = MockBleError.peripheralNotConnected
            } else if !characteristic.properties.contains(.read) {
                localCharacteristic = nil
                localDelay = nil
                localError = MockBleError.operationNotSupported
            } else if let errorOnRead {
                localCharacteristic = nil
                localDelay = nil
                localError = errorOnRead
            } else {
                localDelay = delayOnRead
                if let c = findInternalMutableCharacteristic(characteristic) {
                    localCharacteristic = c
                    localError = nil
                } else {
                    localCharacteristic = nil
                    localError = MockBleError.characteristicNotFound
                }
            }
            lock.unlock()
            
            if let localError {
                localDelegate?.blePeripheral(self, didUpdateValueFor: characteristic, error: localError)
            } else  {
                
                @Sendable
                func _readInternal(_ characteristic: CBCharacteristic) {
                    let localDelegate: BlePeripheralDelegate?
                    lock.lock()
                    localDelegate = peripheralDelegate
                    lock.unlock()
                    localDelegate?.blePeripheral(self, didUpdateValueFor: characteristic, error: nil)
                }
                
                if let localDelay, let localCharacteristic {
                    queue.asyncAfter(deadline: .now() + localDelay) {
                        _readInternal(localCharacteristic)
                    }
                } else if let localCharacteristic {
                    _readInternal(localCharacteristic)
                }
                
            }
            
        }
        
    }
    
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        
        queue.async { [weak self] in
            
            guard let self else { return }

            lock.lock()
            let localDelegate: BlePeripheralDelegate? = peripheralDelegate
            let localError: Error?
            let localDelay: DispatchTimeInterval?
            let localCharacteristic: MockCBCharacteristic?
            if state != .connected {
                localCharacteristic = nil
                localDelay = nil
                localError = MockBleError.peripheralNotConnected
            } else if type == .withResponse && !characteristic.properties.contains(.write) {
                localCharacteristic = nil
                localDelay = nil
                localError = MockBleError.operationNotSupported
            } else if type == .withoutResponse && !characteristic.properties.contains(.writeWithoutResponse) {
                localCharacteristic = nil
                localDelay = nil
                localError = MockBleError.operationNotSupported
            } else if let errorOnWrite {
                localCharacteristic = nil
                localDelay = nil
                localError = errorOnWrite
            } else {
                localDelay = delayOnWrite
                if let c = findInternalMutableCharacteristic(characteristic) {
                    localCharacteristic = c
                    localError = nil
                } else {
                    localCharacteristic = nil
                    localError = MockBleError.characteristicNotFound
                }
            }
            lock.unlock()
            
            if let localError {
                localDelegate?.blePeripheral(self, didWriteValueFor: characteristic, error: localError)
            } else {
                
                @Sendable
                func _writeInternal(_ localCharacteristic: MockCBCharacteristic, _ data: Data) {
                    let localDelegate: BlePeripheralDelegate?
                    lock.lock()
                    localCharacteristic.value = data
                    localDelegate = peripheralDelegate
                    lock.unlock()
                    localDelegate?.blePeripheral(
                        self,
                        didWriteValueFor: localCharacteristic,
                        error: nil)
                }
                
                if let localDelay, let localCharacteristic {
                    queue.asyncAfter(deadline: .now() + localDelay) {
                        _writeInternal(localCharacteristic, data)
                    }
                } else if let localCharacteristic {
                    _writeInternal(localCharacteristic, data)
                }
                
            }
        
        }
        
    }
    
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            lock.lock()
            let localDelegate: BlePeripheralDelegate? = peripheralDelegate
            let localError: Error?
            let localDelay: DispatchTimeInterval?
            let localCharacteristic: MockCBCharacteristic?
            if state != .connected {
                localCharacteristic = nil
                localDelay = nil
                localError = MockBleError.peripheralNotConnected
            } else if !characteristic.properties.contains(.notify) {
                localCharacteristic = nil
                localDelay = nil
                localError = MockBleError.operationNotSupported
            } else if let errorOnNotify {
                localCharacteristic = nil
                localDelay = nil
                localError = errorOnNotify
            } else {
                localDelay = delayOnNotify
                if let c = findInternalMutableCharacteristic(characteristic) {
                    localCharacteristic = c
                    localError = nil
                } else {
                    localCharacteristic = nil
                    localError = MockBleError.characteristicNotFound
                }
            }
            lock.unlock()
            
            if let localError {
                localDelegate?.blePeripheral(self, didUpdateNotificationStateFor: characteristic, error: localError)
            } else {
                
                @Sendable
                func _setNotifyInternal(_ localCharacteristic: MockCBCharacteristic, _ enabled: Bool) {
                    let localDelegate: BlePeripheralDelegate?
                    lock.lock()
                    localCharacteristic.internalIsNotifying = enabled
                    localDelegate = peripheralDelegate
                    lock.unlock()
                    localDelegate?.blePeripheral(
                        self,
                        didUpdateNotificationStateFor: localCharacteristic,
                        error: nil)
                }
                
                if let localDelay, let localCharacteristic {
                    queue.asyncAfter(deadline: .now() + localDelay) {
                        _setNotifyInternal(localCharacteristic, enabled)
                    }
                } else if let localCharacteristic {
                    _setNotifyInternal(localCharacteristic, enabled)
                }
                
            }
            
        }
        
    }
    
    func readRSSI() {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            lock.lock()
            let localDelegate: BlePeripheralDelegate? = peripheralDelegate
            let localError: Error?
            let localDelay: DispatchTimeInterval?
            let localRSSI: Int
            if state != .connected {
                rssi = -1
                localDelay = nil
                localError = MockBleError.peripheralNotConnected
            } else if rssiNotAvailable {
                rssi = 127
                localDelay = nil
                localError = nil
            } else if let errorOnRSSI {
                rssi = -1
                localDelay = nil
                localError = errorOnRSSI
            } else {
                rssi = Int.random(in: (-90)...(-50))
                localError = nil
                localDelay = delayOnRSSI
            }
            localRSSI = rssi
            lock.unlock()
            
            if let localError {
                localDelegate?.blePeripheral(self, didReadRSSI: localRSSI, error: localError)
            } else {
                
                @Sendable
                func _readRssiInternal() {
                    let localDelegate: BlePeripheralDelegate?
                    lock.lock()
                    localDelegate = peripheralDelegate
                    lock.unlock()
                    localDelegate?.blePeripheral(self, didReadRSSI: localRSSI, error: localError)
                }
                
                if let localDelay {
                    queue.asyncAfter(deadline: .now() + localDelay) {
                        _readRssiInternal()
                    }
                } else {
                    _readRssiInternal()
                }
            }
            
        }
        
    }
    
    func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        return 180
    }
    
    // MARK: - Internal characteristics discovery
    
    private func discoverDeviceInformationServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
        
        lock.lock()
        let localDelegate: BlePeripheralDelegate? = peripheralDelegate
        let localService: CBService = deviceInformationService
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.serialNumberCharacteristicUUID,
                properties: [.read],
                value: serialNumber.data(using: .utf8),
                permissions: .readable),
            to: deviceInformationService,
            characteristicUUIDs: characteristicUUIDs)
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.firmwareRevisionCharacteristicUUID,
                properties: [.read],
                value: firmwareRevision.data(using: .utf8),
                permissions: .readable),
            to: deviceInformationService,
            characteristicUUIDs: characteristicUUIDs)
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.hardwareRevisionCharacteristicUUID,
                properties: [.read],
                value: hardwareRevision.data(using: .utf8),
                permissions: .readable),
            to: deviceInformationService,
            characteristicUUIDs: characteristicUUIDs)
        lock.unlock()
        
        localDelegate?.blePeripheral(self, didDiscoverCharacteristicsFor: localService, error: nil)
        
    }
    
    private func discoverBatteryServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {

        lock.lock()
        let localDelegate: BlePeripheralDelegate? = peripheralDelegate
        let localService: CBService = batteryService
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.batteryLevelCharacteristicUUID,
                properties: [.read],
                value: Data(with: batteryLevel),
                permissions: .readable),
            to: batteryService,
            characteristicUUIDs: characteristicUUIDs)
        lock.unlock()
        
        localDelegate?.blePeripheral(self, didDiscoverCharacteristicsFor: localService, error: nil)
        
    }
    
    private func discoverHeartRateServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
      
        lock.lock()
        let localDelegate: BlePeripheralDelegate? = peripheralDelegate
        let localService: CBService = heartRateService
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.heartRateCharacteristicUUID,
                properties: [.read, .notify],
                value: Data(with: heartRateProvider()),
                permissions: .readable),
            to: heartRateService,
            characteristicUUIDs: characteristicUUIDs)
        lock.unlock()
        
        localDelegate?.blePeripheral(self, didDiscoverCharacteristicsFor: localService, error: nil)
        
    }
    
    private func discoverCustomServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
        
        lock.lock()
        let localDelegate: BlePeripheralDelegate? = peripheralDelegate
        let localService: CBService = customService
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.secretCharacteristicUUID,
                properties: [.write],
                value: secret.data(using: .utf8),
                permissions: .writeable),
            to: customService,
            characteristicUUIDs: characteristicUUIDs)
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.bufferCharacteristicUUID,
                properties: [.writeWithoutResponse],
                value: Data(),
                permissions: .writeable),
            to: customService,
            characteristicUUIDs: characteristicUUIDs)
        lock.unlock()
        
        localDelegate?.blePeripheral(self, didDiscoverCharacteristicsFor: localService, error: nil)
        
    }
    
    // MARK: - Internals
    
    private func addCharacteristicIfNeeded(_ characteristic: MockCBCharacteristic, to service: CBMutableService, characteristicUUIDs: [CBUUID]?) {
        service.characteristics = service.characteristics.emptyIfNil
        guard characteristicUUIDs == nil || characteristicUUIDs!.contains(characteristic.uuid) else { return }
        guard findInternalMutableCharacteristic(characteristic) == nil else { return }
        service.characteristics?.append(characteristic)
    }
    
    private func findInternalMutableCharacteristic(_ characteristic: CBCharacteristic) -> MockCBCharacteristic? {
        return findInternalMutableCharacteristic(characteristic.uuid)
    }
    
    private func findInternalMutableCharacteristic(_ characteristicUUID: CBUUID) -> MockCBCharacteristic? {
        let service = services?.first {
            $0.characteristics?.contains { characteristic in
                characteristic.uuid == characteristicUUID
            } ?? false
        }
        return service?.characteristics?.first {
            $0.uuid == characteristicUUID
        } as? MockCBCharacteristic
    }
    
    // MARK: - Internal notify
    
    private func startNotify() {
        lock.lock()
        defer { lock.unlock() }
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + .seconds(1), repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.notifyInterval()
        }
        timer?.resume()
    }
    
    private func stopNotify() {
        lock.lock()
        defer { lock.unlock() }
        timer?.cancel()
        timer = nil
    }
    
    private func notifyInterval() {
        
        lock.lock()
        let localDelegate: BlePeripheralDelegate? = peripheralDelegate
        let localServices: [CBService]? = services
        let localCharacteristic: MockCBCharacteristic? = findInternalMutableCharacteristic(MockBleDescriptor.heartRateCharacteristicUUID)
        localCharacteristic?.value = Data(with: heartRateProvider())
        lock.unlock()
        
        localServices?.forEach {
            $0.characteristics?.forEach { characteristic in
                if characteristic.isNotifying, characteristic.value != nil {
                    localDelegate?.blePeripheral(self, didUpdateValueFor: characteristic, error: nil)
                }
            }
        }
    
    }
    
    // MARK: - Utils
    
    func readRSSI(after timeout: DispatchTimeInterval) {
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.readRSSI()
        }
    }
    
    func setName(_ name: String?, after timeout: DispatchTimeInterval) {
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self else { return }
            lock.lock()
            let localDelegate: BlePeripheralDelegate? = peripheralDelegate
            self.name = name
            lock.unlock()
            localDelegate?.blePeripheralDidUpdateName(self)
        }
    }
    
}
