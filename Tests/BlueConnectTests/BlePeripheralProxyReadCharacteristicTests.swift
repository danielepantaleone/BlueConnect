//
//  BlePeripheralProxyReadCharacteristicTests.swift
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

import Combine
@preconcurrency import CoreBluetooth
import Foundation
import XCTest

@testable import BlueConnect

final class BlePeripheralProxyReadCharacteristicTests: BlueConnectTests {
    
    // MARK: - Properties
    
    var blePeripheralProxy_1: BlePeripheralProxy!
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        blePeripheralProxy_1 = .init(peripheral: try blePeripheral_1)
    }
    
    override func tearDownWithError() throws {
        blePeripheralProxy_1 = nil
        try super.tearDownWithError()
    }
    
}

// MARK: - Read characteristic tests
    
extension BlePeripheralProxyReadCharacteristicTests {
        
    func testReadCharacteristic() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic to be read")
        let publisherExp = expectation(description: "waiting for characteristic update to be signaled by publisher")
        // Test read emit on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .filter { String(data: $0.data, encoding: .utf8) == "12345678" }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read on callback
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let serialNumber = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID]
                    XCTAssertEqual(serialNumber, "12345678")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    readExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadCharacteristicWithMultipleConcurrentRead() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock read delay
        try blePeripheral_1.delayOnRead = .seconds(2)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic to be read")
        readExp.expectedFulfillmentCount = 2
        let publisherExp = expectation(description: "waiting for characteristic update to be signaled by publisher")
        // Test single read emit on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .filter { String(data: $0.data, encoding: .utf8) == "12345678" }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test multiple read on callback
        for _ in 0..<2 {
            blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                cachePolicy: .never,
                timeout: .never
            ) { [weak self] result in
                guard let self else { return }
                switch result {
                    case .success(let data):
                        let serialNumber = String(data: data, encoding: .utf8)
                        let record = blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID]
                        XCTAssertEqual(serialNumber, "12345678")
                        XCTAssertEqual(record?.data, data)
                        XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                        readExp.fulfill()
                    case .failure(let error):
                        XCTFail("characteristic read failed with error: \(error)")
                }
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
    }
    
    func testReadCharacteristicWithCacheAlwaysPolicy() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Read from the peripheral so the value gets cached
        try read(characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID, on: blePeripheralProxy_1)
        // Change characteristic value manually to assert read from cache
        let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID)
        let mutable = characteristic as? CBMutableCharacteristic
        mutable?.value = "2.0.0".data(using: .utf8)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic to be read")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher due to cached value read")
        publisherExp.isInverted = true
        // Test read not emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.firmwareRevisionCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read on callback
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID,
            cachePolicy: .always,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let firmwareRevision = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.firmwareRevisionCharacteristicUUID]
                    XCTAssertEqual(firmwareRevision, "1.0.7")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.firmwareRevisionCharacteristicUUID), [])
                    let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID)
                    let firmwareRevisionOnCharacteristic = characteristic?.value.map { String(data: $0, encoding: .utf8) }
                    XCTAssertEqual(firmwareRevisionOnCharacteristic, "2.0.0")
                    readExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadCharacteristicWithCacheTimeSensitivePolicy() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Read from the peripheral so the value gets cached
        try read(characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID, on: blePeripheralProxy_1)
        // Change characteristic value manually to assert read from cache
        let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID)
        let mutable = characteristic as? CBMutableCharacteristic
        mutable?.value = "2.0.0".data(using: .utf8)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic to be read")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher due to cached value read")
        publisherExp.isInverted = true
        // Test read not emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.firmwareRevisionCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read on callback
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID,
            cachePolicy: .timeSensitive(.seconds(4)),
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let firmwareRevision = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.firmwareRevisionCharacteristicUUID]
                    XCTAssertEqual(firmwareRevision, "1.0.7")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.firmwareRevisionCharacteristicUUID), [])
                    let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID)
                    let firmwareRevisionOnCharacteristic = characteristic?.value.map { String(data: $0, encoding: .utf8) }
                    XCTAssertEqual(firmwareRevisionOnCharacteristic, "2.0.0")
                    readExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadCharacteristicWithCacheTimeSensitivePolicyOverdue() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Read from the peripheral so the value gets cached
        let data = try read(characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID, on: blePeripheralProxy_1)
        let firmwareRevision = String(data: data, encoding: .utf8)
        XCTAssertEqual(firmwareRevision, "1.0.7")
        // Change characteristic value manually to assert read is not from cache
        let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID)
        let mutable = characteristic as? CBMutableCharacteristic
        mutable?.value = "2.0.0".data(using: .utf8)
        // Wait to let cache expire
        wait(.seconds(3))
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic to be read")
        let publisherExp = expectation(description: "waiting for characteristic update to be signaled by publisher due to cached value bypass")
        // Test single read emit on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.firmwareRevisionCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test multiple read on callback
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID,
            cachePolicy: .timeSensitive(.seconds(2)),
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let firmwareRevision = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.firmwareRevisionCharacteristicUUID]
                    XCTAssertEqual(firmwareRevision, "2.0.0")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.firmwareRevisionCharacteristicUUID), [])
                    readExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 6.0)
    }
    
    func testReadCharacteristicFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read NOT emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read to fail
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadCharacteristicFailDueToCharacteristicNotFound() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read NOT emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read to fail
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadCharacteristicFailDueToOperationNotSupported() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read NOT emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read to fail
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.secretCharacteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .readNotSupported(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'readNotSupported', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.secretCharacteristicUUID])
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadCharacteristicFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock read timeout
        try blePeripheral_1.delayOnRead = .seconds(10)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read NOT emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read to fail
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            cachePolicy: .never,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .readTimeout(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'readTimeout', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
    }
    
    func testReadCharacteristicFailDueToError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock read error
        try blePeripheral_1.errorOnRead = MockBleError.mockedError
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read NOT emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read to fail
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let mockedError = error as? MockBleError else {
                        XCTFail("characteristic read was expected to fail with MockBleError, got '\(error)' instead")
                        return
                    }
                    guard case .mockedError = mockedError else {
                        XCTFail("characteristic read was expected to fail with MockBleError 'mockedError', got '\(mockedError)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
    }
    
    func testReadCharacteristicFailDueToNilData() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Change characteristic value manually to nil
        let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID)
        let mutable = characteristic as? CBMutableCharacteristic
        mutable?.value = nil
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read NOT emitted on publisher
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read to fail
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicDataIsNil(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'characteristicDataIsNil', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.secretCharacteristicUUID])
                    XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
    }
    
    func testReadCharacteristicFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock read delay
        try blePeripheral_1.delayOnRead = .seconds(2)
        // Test read to fail
        let expectation = expectation(description: "waiting for characteristic read to fail")
        blePeripheralProxy_1.read(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .destroyed = proxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'destroyed', got '\(proxyError)' instead")
                        return
                    }
                    expectation.fulfill()
            }
        }
        // Destroy the proxy
        blePeripheralProxy_1 = nil
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
}

// MARK: - Read characteristic tests (async)
    
extension BlePeripheralProxyReadCharacteristicTests {
    
    func testReadCharacteristicAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic read
        do {
            let data = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                cachePolicy: .never,
                timeout: .never)
            let serialNumber = String(data: data, encoding: .utf8)
            let record = blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID]
            XCTAssertEqual(serialNumber, "12345678")
            XCTAssertEqual(record?.data, data)
            XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic read failed with error: \(error)")
        }
    }
    
    func testReadCharacteristicFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                cachePolicy: .never,
                timeout: .never)
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testReadCharacteristicFailDueToCharacteristicNotFoundAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                cachePolicy: .never,
                timeout: .never)
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
    func testReadCharacteristicFailDueToOperationNotSupportedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.secretCharacteristicUUID,
                cachePolicy: .never,
                timeout: .never)
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.readNotSupported(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.secretCharacteristicUUID])
            XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'readNotSupported', got '\(error)' instead")
        }
    }
    
    func testReadCharacteristicFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock read timeout
        try blePeripheral_1.delayOnRead = .seconds(10)
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                cachePolicy: .never,
                timeout: .seconds(2))
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.readTimeout(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'readTimeout', got '\(error)' instead")
        }
    }
    
    func testReadCharacteristicFailDueToErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock read error
        try blePeripheral_1.errorOnRead = MockBleError.mockedError
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                cachePolicy: .never,
                timeout: .never)
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch MockBleError.mockedError {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic read was expected to fail with MockBleError 'mockedError', got '\(error)' instead")
        }
    }
    
    func testReadCharacteristicFailDueToNilDataAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Change characteristic value manually to nil
        let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID)
        let mutable = characteristic as? CBMutableCharacteristic
        mutable?.value = nil
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                cachePolicy: .never,
                timeout: .seconds(2))
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicDataIsNil(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertEqual(blePeripheralProxy_1.characteristicReadRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError 'characteristicDataIsNil', got '\(error)' instead")
        }
    }
    
}
