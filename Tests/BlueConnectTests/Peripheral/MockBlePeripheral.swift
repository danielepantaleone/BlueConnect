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

import CoreBluetooth
import Foundation

@testable import BlueConnect

class MockBlePeripheral: BlePeripheral {
        
    // MARK: - Protocol properties
    
    var identifier: UUID
    var name: String? {
        didSet {
            queue.async { [weak self] in
                guard let self else { return }
                peripheralDelegate?.blePeripheralDidUpdateName(self)
            }
        }
    }
    var services: [CBService]? = nil
    var state: CBPeripheralState = .disconnected {
        didSet {
            if state == .connected {
                startNotify()
            } else {
                stopNotify()
            }
        }
    }
    
    weak var peripheralDelegate: BlePeripheralDelegate?
    
    // MARK: - Properties
    
    var rssi: Int = -80
    var heartRateProvider: () -> Int = { 90 }
    var errorOnDiscoverServices: Error?
    var errorOnDiscoverCharacteristics: Error?
    var errorOnRead: Error?
    var errorOnWrite: Error?
    var errorOnNotify: Error?
    var delayOnDiscoverServices: DispatchTimeInterval?
    var delayOnDiscoverCharacteristics: DispatchTimeInterval?
    var delayOnRead: DispatchTimeInterval?
    var delayOnWrite: DispatchTimeInterval?
    var delayOnNotify: DispatchTimeInterval?
    
    // MARK: - Private properties
    
    private let serialNumber: String
    private let batteryLevel: Int
    private let firmwareRevision: String
    private let hardwareRevision: String
    private let secret: String
    private let mutex = RecursiveMutex()
    private var timer: DispatchSourceTimer?
    
    // MARK: - Services
    
    private let deviceInformationService = CBMutableService(type: MockBleDescriptor.deviceInformationServiceUUID, primary: false)
    private let batteryService = CBMutableService(type: MockBleDescriptor.batteryServiceUUID, primary: false)
    private let heartRateService = CBMutableService(type: MockBleDescriptor.heartRateServiceUUID, primary: false)
    private let customService = CBMutableService(type: MockBleDescriptor.customServiceUUID, primary: false)
    
    lazy var queue: DispatchQueue = DispatchQueue.global(qos: .background)
    
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
            mutex.lock()
            defer { mutex.unlock() }
            guard state == .connected else {
                peripheralDelegate?.blePeripheral(self, didDiscoverServices: MockBleError.peripheralNotConnected)
                return
            }
            guard errorOnDiscoverServices == nil else {
                peripheralDelegate?.blePeripheral(self, didDiscoverServices: errorOnDiscoverServices)
                errorOnDiscoverServices = nil
                return
            }
            func _discoverServicesInternal() {
                mutex.lock()
                defer { mutex.unlock() }
                services = services.emptyIfNil
                let allServices = [deviceInformationService, batteryService, heartRateService, customService]
                if let serviceUUIDs {
                    allServices.forEach { service in
                        guard serviceUUIDs.contains(where: { $0 == service.uuid }) else { return }
                        guard !self.services!.contains(service) else { return }
                        self.services!.append(service)
                    }
                } else {
                    allServices.forEach { service in
                        guard !self.services!.contains(service) else { return }
                        self.services!.append(service)
                    }
                }
                peripheralDelegate?.blePeripheral(self, didDiscoverServices: nil)
            }
            if let delayOnDiscoverServices {
                queue.asyncAfter(deadline: .now() + delayOnDiscoverServices) {
                    _discoverServicesInternal()
                }
                self.delayOnDiscoverServices = nil
            } else {
                _discoverServicesInternal()
            }
        }
    }
    
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        queue.async { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            guard errorOnDiscoverCharacteristics == nil else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didDiscoverCharacteristicsFor: service,
                    error: errorOnDiscoverCharacteristics)
                errorOnDiscoverCharacteristics = nil
                return
            }
            func _discoverCharacteristicsInternal() {
                if service == deviceInformationService {
                    discoverDeviceInformationServiceCharacteristics(characteristicUUIDs)
                } else if service == batteryService {
                    discoverBatteryServiceCharacteristics(characteristicUUIDs)
                } else if service == heartRateService {
                    discoverHeartRateServiceCharacteristics(characteristicUUIDs)
                } else if service == customService {
                    discoverCustomServiceCharacteristics(characteristicUUIDs)
                }
            }
            if let delayOnDiscoverCharacteristics {
                queue.asyncAfter(deadline: .now() + delayOnDiscoverCharacteristics) {
                    _discoverCharacteristicsInternal()
                }
                self.delayOnDiscoverCharacteristics = nil
            } else {
                _discoverCharacteristicsInternal()
            }
        }
    }
    
    func readValue(for characteristic: CBCharacteristic) {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            mutex.lock()
            defer { mutex.unlock() }
            
            guard state == .connected else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.peripheralNotConnected)
                return
            }
            guard characteristic.properties.contains(.read) else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.operationNotSupported)
                return
            }
            guard let internalCharacteristic = findInternalMutableCharacteristic(characteristic) else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.characteristicNotFound)
                return
            }
            guard errorOnRead == nil else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: internalCharacteristic,
                    error: errorOnRead)
                errorOnRead = nil
                return
            }
            func _readInternal() {
                mutex.lock()
                defer { mutex.unlock() }
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: internalCharacteristic,
                    error: nil)
            }
            if let delayOnRead {
                queue.asyncAfter(deadline: .now() + delayOnRead) {
                    _readInternal()
                }
                self.delayOnRead = nil
            } else {
                _readInternal()
            }
            
        }
        
    }
    
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        
        queue.async { [weak self] in
            
            guard let self else { return }
            
            mutex.lock()
            defer { mutex.unlock() }
            
            guard state == .connected else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.peripheralNotConnected)
                return
            }
            if type == .withResponse {
                guard characteristic.properties.contains(.write) else {
                    peripheralDelegate?.blePeripheral(
                        self,
                        didUpdateValueFor: characteristic,
                        error: MockBleError.operationNotSupported)
                    return
                }
            } else {
                guard characteristic.properties.contains(.writeWithoutResponse) else {
                    peripheralDelegate?.blePeripheral(
                        self,
                        didUpdateValueFor: characteristic,
                        error: MockBleError.operationNotSupported)
                    return
                }
            }
            guard let internalCharacteristic = findInternalMutableCharacteristic(characteristic) else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.characteristicNotFound)
                return
            }
            guard errorOnWrite == nil else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didWriteValueFor: internalCharacteristic,
                    error: errorOnWrite
                )
                errorOnWrite = nil
                return
            }
            func _writeInternal() {
                mutex.lock()
                defer { mutex.unlock() }
                internalCharacteristic.value = data
                peripheralDelegate?.blePeripheral(
                    self,
                    didWriteValueFor: internalCharacteristic,
                    error: nil)
            }
            if let delayOnWrite {
                queue.asyncAfter(deadline: .now() + delayOnWrite) {
                    _writeInternal()
                }
                self.delayOnWrite = nil
            } else {
                _writeInternal()
            }
        
        }
        
    }
    
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        queue.async { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            guard state == .connected else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.peripheralNotConnected)
                return
            }
            guard characteristic.properties.contains(.notify) else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.operationNotSupported)
                return
            }
            guard let internalCharacteristic = findInternalMutableCharacteristic(characteristic) else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateValueFor: characteristic,
                    error: MockBleError.characteristicNotFound)
                return
            }
            guard errorOnNotify == nil else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateNotificationStateFor: internalCharacteristic,
                    error: errorOnNotify
                )
                errorOnNotify = nil
                return
            }
            func _notifyInternal() {
                mutex.lock()
                defer { mutex.unlock() }
                internalCharacteristic.internalIsNotifying = enabled
                peripheralDelegate?.blePeripheral(
                    self,
                    didUpdateNotificationStateFor: internalCharacteristic,
                    error: nil)
            }
            if let delayOnNotify {
                queue.asyncAfter(deadline: .now() + delayOnNotify) {
                    _notifyInternal()
                }
                self.delayOnNotify = nil
            } else {
                _notifyInternal()
            }
        }
    }
    
    func readRSSI() {
        queue.async { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            guard state == .connected else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didReadRSSI: NSNumber(value: -1),
                    error: MockBleError.peripheralNotConnected)
                return
            }
            rssi = Int.random(in: (-90)...(-50))
            peripheralDelegate?.blePeripheral(
                self,
                didReadRSSI: NSNumber(value: rssi),
                error: nil)
        }
    }
    
    func maximumWriteValueLength(for: CBCharacteristicWriteType) -> Int {
        return 180
    }
    
    // MARK: - Internal characteristics discovery
    
    private func discoverDeviceInformationServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: deviceInformationService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
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
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: deviceInformationService,
            error: nil)
        
    }
    
    private func discoverBatteryServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: batteryService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.batteryLevelCharacteristicUUID,
                properties: [.read],
                value: Data(with: batteryLevel),
                permissions: .readable),
            to: batteryService,
            characteristicUUIDs: characteristicUUIDs)
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: batteryService,
            error: nil)
        
    }
    
    private func discoverHeartRateServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: heartRateService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
        addCharacteristicIfNeeded(
            MockCBCharacteristic(
                type: MockBleDescriptor.heartRateCharacteristicUUID,
                properties: [.read, .notify],
                value: Data(with: heartRateProvider()),
                permissions: .readable),
            to: heartRateService,
            characteristicUUIDs: characteristicUUIDs)
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: heartRateService,
            error: nil)
        
    }
    
    private func discoverCustomServiceCharacteristics(_ characteristicUUIDs: [CBUUID]?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: customService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
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
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: customService,
            error: nil)
        
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
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(queue: .global())
        timer?.schedule(deadline: .now() + .seconds(1), repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            guard let self else { return }
            notifyInterval()
        }
        timer?.resume()
    }
    
    private func stopNotify() {
        timer?.cancel()
        timer = nil
    }
    
    private func notifyInterval() {
        mutex.lock()
        defer { mutex.unlock() }
        let characteristic = findInternalMutableCharacteristic(MockBleDescriptor.heartRateCharacteristicUUID)
        characteristic?.value = Data(with: heartRateProvider())
        services?.forEach {
            $0.characteristics?.forEach { characteristic in
                if characteristic.isNotifying, characteristic.value != nil {
                    peripheralDelegate?.blePeripheral(
                        self,
                        didUpdateValueFor: characteristic,
                        error: nil)
                }
            }
        }
    }
    
    // MARK: - Utils
    
    func readRSSI(after timeout: DispatchTimeInterval) {
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            self.readRSSI()
        }
    }
    
    func setName(_ name: String?, after timeout: DispatchTimeInterval) {
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            self.name = name
        }
    }
    
}
