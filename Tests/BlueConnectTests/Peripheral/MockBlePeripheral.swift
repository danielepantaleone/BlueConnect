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
    
    let identifier: UUID
    let name: String?
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
    
    var rssi: Int32 = -80
    var heartRateProvider: () -> Int = { 90 }
    var errorOnDiscoverServices: Error?
    var errorOnDiscoverCharacteristics: Error?
    var errorOnRead: Error?
    var errorOnWrite: Error?
    var errorOnNotify: Error?
    var timeoutOnDiscoverServices: Bool = false
    var timeoutOnDiscoverCharacteristics: Bool = false
    var timeoutOnRead: Bool = false
    var timeoutOnWrite: Bool = false
    var timeoutOnNotify: Bool = false
    var delayOnDiscoverServices: TimeInterval?
    var delayOnDiscoverCharacteristics: TimeInterval?
    var delayOnRead: TimeInterval?
    var delayOnWrite: TimeInterval?
    var delayOnNotify: TimeInterval?
    
    // MARK: - Private properties
    
    private let serialNumber: String
    private let batteryLevel: Int
    private let firmwareRevision: String
    private let hardwareRevision: String
    private let secret: String
    private let mutex = RecursiveCondition()
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
            guard !timeoutOnDiscoverServices else {
                timeoutOnDiscoverServices = false
                return
            }
            guard errorOnDiscoverServices == nil else {
                peripheralDelegate?.blePeripheral(self, didDiscoverServices: errorOnDiscoverServices)
                errorOnDiscoverServices = nil
                return
            }
            if let delayOnDiscoverServices {
                self.mutex.wait(timeout: delayOnDiscoverServices)
                self.delayOnDiscoverServices = nil
            }
            services = services.emptyIfNil
            let allServices = [deviceInformationService, batteryService, heartRateService, customService]
            if let serviceUUIDs {
                allServices.forEach { service in
                    if serviceUUIDs.contains(where: { $0.uuidString == service.uuid.uuidString }) {
                        let service = service as CBService
                        if !self.services!.contains(service) {
                            self.services!.append(service)
                        }
                    }
                }
            } else {
                allServices.forEach {
                    if !self.services!.contains($0) {
                        self.services?.append($0)
                    }
                }
            }
            services?.compactMap { $0 as? CBMutableService }.forEach {
                $0.characteristics = $0.characteristics.emptyIfNil
            }
            peripheralDelegate?.blePeripheral(self, didDiscoverServices: nil)
        }
    }
    
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        queue.async { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            guard !timeoutOnDiscoverCharacteristics else {
                timeoutOnDiscoverCharacteristics = false
                return
            }
            guard errorOnDiscoverCharacteristics == nil else {
                peripheralDelegate?.blePeripheral(
                    self,
                    didDiscoverCharacteristicsFor: service,
                    error: errorOnDiscoverCharacteristics)
                errorOnDiscoverCharacteristics = nil
                return
            }
            if let delayOnDiscoverCharacteristics {
                self.mutex.wait(timeout: delayOnDiscoverCharacteristics)
                self.delayOnDiscoverCharacteristics = nil
            }
            if service == deviceInformationService {
                discoverDeviceInformationServiceCharacteristics()
            } else if service == batteryService {
                discoverBatteryServiceCharacteristics()
            } else if service == heartRateService {
                discoverHeartRateServiceCharacteristics()
            } else if service == customService {
                discoverCustomServiceCharacteristics()
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
            guard !timeoutOnRead else {
                timeoutOnRead = false
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
            if let delayOnRead {
                self.mutex.wait(timeout: delayOnRead)
                self.delayOnRead = nil
            }
            peripheralDelegate?.blePeripheral(
                self,
                didUpdateValueFor: internalCharacteristic,
                error: nil)
            
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
            guard !timeoutOnWrite else {
                timeoutOnWrite = false
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
            if let delayOnWrite {
                self.mutex.wait(timeout: delayOnWrite)
                self.delayOnWrite = nil
            }
            internalCharacteristic.value = data
            peripheralDelegate?.blePeripheral(
                self,
                didWriteValueFor: internalCharacteristic,
                error: nil)
            
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
            guard !timeoutOnNotify else {
                timeoutOnNotify = false
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
            if let delayOnNotify {
                self.mutex.wait(timeout: delayOnNotify)
                self.delayOnNotify = nil
            }
            internalCharacteristic.internalIsNotifying = enabled
            peripheralDelegate?.blePeripheral(
                self,
                didUpdateNotificationStateFor: internalCharacteristic,
                error: nil)
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
            peripheralDelegate?.blePeripheral(
                self,
                didReadRSSI: NSNumber(value: rssi),
                error: nil)
        }
    }
    
    func maximumWriteValueLength(for: CBCharacteristicWriteType) -> Int {
        return 180
    }
    
    // MARK: - Characteristics discovery
    
    private func discoverDeviceInformationServiceCharacteristics() {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: deviceInformationService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
        addCharacteristicsIfNeeded([
            
            MockCBCharacteristic(
                type: MockBleDescriptor.serialNumberCharacteristicUUID,
                properties: [.read],
                value: Data(serialNumber.utf8),
                permissions: .readable),
            
            MockCBCharacteristic(
                type: MockBleDescriptor.firmwareRevisionCharacteristicUUID,
                properties: [.read],
                value: Data(firmwareRevision.utf8),
                permissions: .readable),
            
            MockCBCharacteristic(
                type: MockBleDescriptor.hardwareRevisionCharacteristicUUID,
                properties: [.read],
                value: Data(hardwareRevision.utf8),
                permissions: .readable)
            
        ], to: deviceInformationService)
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: deviceInformationService,
            error: nil)
        
    }
    
    private func discoverBatteryServiceCharacteristics() {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: batteryService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
        addCharacteristicsIfNeeded([
            MockCBCharacteristic(
                type: MockBleDescriptor.batteryLevelCharacteristicUUID,
                properties: [.read],
                value: Data(with: batteryLevel),
                permissions: .readable)
        ], to: batteryService)
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: batteryService,
            error: nil)
        
    }
    
    private func discoverHeartRateServiceCharacteristics() {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: heartRateService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
        addCharacteristicsIfNeeded([
            MockCBCharacteristic(
                type: MockBleDescriptor.heartRateCharacteristicUUID,
                properties: [.read, .notify],
                value: Data(with: heartRateProvider()),
                permissions: .readable)
        ], to: batteryService)
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: heartRateService,
            error: nil)
        
    }
    
    private func discoverCustomServiceCharacteristics() {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard state == .connected else {
            peripheralDelegate?.blePeripheral(
                self,
                didDiscoverCharacteristicsFor: customService,
                error: MockBleError.peripheralNotConnected)
            return
        }
        
        addCharacteristicsIfNeeded([
            
            MockCBCharacteristic(
                type: MockBleDescriptor.secretCharacteristicUUID,
                properties: [.write],
                value: Data(secret.utf8),
                permissions: .writeable),
            
            MockCBCharacteristic(
                type: MockBleDescriptor.bufferCharacteristicUUID,
                properties: [.writeWithoutResponse],
                value: Data([0x00]),
                permissions: .writeable),
            
        ], to: customService)
        
        peripheralDelegate?.blePeripheral(
            self,
            didDiscoverCharacteristicsFor: customService,
            error: nil)
        
    }
    
    // MARK: - Internals
    
    private func addCharacteristicsIfNeeded(_ characteristics: [MockCBCharacteristic], to service: CBMutableService) {
        service.characteristics = service.characteristics.emptyIfNil
        characteristics.forEach {
            if findInternalMutableCharacteristic($0) == nil {
                service.characteristics?.append($0)
            }
        }
    }
    
    private func findInternalMutableCharacteristic(_ characteristic: CBCharacteristic) -> MockCBCharacteristic? {
        return findInternalMutableCharacteristic(characteristic.uuid)
    }
    
    private func findInternalMutableCharacteristic(_ characteristicUUID: CBUUID) -> MockCBCharacteristic? {
        let service = services?.first {
            $0.characteristics?.contains { characteristic in
                characteristic.uuid.uuidString == characteristicUUID.uuidString
            } ?? false
        }
        return service?.characteristics?.first {
            $0.uuid.uuidString == characteristicUUID.uuidString
        } as? MockCBCharacteristic
    }
    
    // MARK: - Notify
    
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
    
}