//
//  BlePeripheralProxyDiscoverCharacteristicTests.swift
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
#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation
import XCTest

@testable import BlueConnect

final class BlePeripheralProxyDiscoverCharacteristicTests: BlueConnectTests {
    
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

// MARK: - Discover characteristic tests

extension BlePeripheralProxyDiscoverCharacteristicTests {
    
    func testDiscoverCharacteristic() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic discovery
        let discoveryExp = expectation(description: "waiting for characteristic to be discovered")
        let publisherExp = expectation(description: "waiting for characteristic discovery to be signaled by publisher")
        // Test discovery emit on publisher
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.heartRateServiceUUID && $1.contains(where: { $0.uuid == MockBleDescriptor.heartRateCharacteristicUUID })}
            .sink { _ in publisherExp.fulfill() }
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
            in: MockBleDescriptor.heartRateServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let characteristic):
                    XCTAssertEqual(characteristic.uuid, MockBleDescriptor.heartRateCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testDiscoverCharacteristicWithCharacteristicAlreadyDiscovered() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test second discovery
        let discoveryExp = expectation(description: "waiting for characteristic discovery")
        let publisherExp = expectation(description: "waiting for characteristic discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.deviceInformationServiceUUID && $1.contains(where: { $0.uuid == MockBleDescriptor.serialNumberCharacteristicUUID })}
            .sink { _ in publisherExp.fulfill() }
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            in: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let characteristic):
                    XCTAssertEqual(characteristic.uuid, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testDiscoverCharacteristicWithMixedCharacteristicDiscovery() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover a characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test second discovery
        let discoveryExp = expectation(description: "waiting for characteristic discovery even if already discovered")
        let publisherExp = expectation(description: "waiting for characteristic discovery NOT to be signaled by publisher")
        publisherExp.expectedFulfillmentCount = 2
        // Test publisher to be called
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.deviceInformationServiceUUID && $1.contains(where: { $0.uuid == MockBleDescriptor.firmwareRevisionCharacteristicUUID })}
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.firmwareRevisionCharacteristicUUID,
            in: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let characteristic):
                    XCTAssertEqual(characteristic.uuid, MockBleDescriptor.firmwareRevisionCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.firmwareRevisionCharacteristicUUID), [])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testDiscoverCharacteristics() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristics discovery
        let expectation = expectation(description: "waiting for characteristics discovery to be signaled by publisher")
        expectation.expectedFulfillmentCount = 2
        // Test discovery emit on publisher
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in expectation.fulfill() } }
        blePeripheralProxy_1.discover(
            characteristicUUIDs: [
                MockBleDescriptor.serialNumberCharacteristicUUID,
                MockBleDescriptor.firmwareRevisionCharacteristicUUID
            ],
            in: MockBleDescriptor.deviceInformationServiceUUID)
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
        subscription.cancel()
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID))
        XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.hardwareRevisionCharacteristicUUID))
        XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.firmwareRevisionCharacteristicUUID), [])
    }
    
    func testDiscoverCharacteristicsWithNoArguments() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristics discovery
        let expectation = expectation(description: "waiting for characteristics discovery to be signaled by publisher")
        expectation.expectedFulfillmentCount = 3
        // Test discovery emit on publisher
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in expectation.fulfill() } }
        blePeripheralProxy_1.discover(
            characteristicUUIDs: nil,
            in: MockBleDescriptor.deviceInformationServiceUUID)
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
        subscription.cancel()
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID))
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.hardwareRevisionCharacteristicUUID))
        XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.firmwareRevisionCharacteristicUUID), [])
        XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.hardwareRevisionCharacteristicUUID), [])
    }
    
    func testDiscoverCharacteristicFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test characteristic discovery
        let discoveryExp = expectation(description: "waiting for characteristic discovery to fail")
        let publisherExp = expectation(description: "waiting for characteristic discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            in: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testDiscoverCharacteristicFailDueToServiceNotFound() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic discovery
        let discoveryExp = expectation(description: "waiting for characteristic discovery to fail")
        let publisherExp = expectation(description: "waiting for characteristic discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            in: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .serviceNotFound(let serviceUUID) = proxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(serviceUUID, MockBleDescriptor.deviceInformationServiceUUID)
                    XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testDiscoverCharacteristicFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock characteristic discovery timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic discovery
        let discoveryExp = expectation(description: "waiting for characteristic discovery to fail")
        let publisherExp = expectation(description: "waiting for characteristic discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            in: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 4.0)
        subscription.cancel()
    }
    
    func testDiscoverCharacteristicFailDueToError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock discovery error
        try blePeripheral_1.errorOnDiscoverCharacteristics = MockBleError.mockedError
        // Test characteristic discovery
        let discoveryExp = expectation(description: "waiting for characteristic discovery to fail")
        let publisherExp = expectation(description: "waiting for characteristic discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        let subscription = blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            in: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 4.0)
        subscription.cancel()
    }
    
    func testDiscoverCharacteristicFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock discovery delay
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(2)
        // Test discovery failure
        let expectation = expectation(description: "waiting for characteristic discovery to fail")
        blePeripheralProxy_1.discover(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            in: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .destroyed = proxyError else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'destroyed', got '\(proxyError)' instead")
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

// MARK: - Discover characteristic tests (async)

extension BlePeripheralProxyDiscoverCharacteristicTests {
    
    func testDiscoverCharacteristicAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic discovery
        do {
            let characteristic = try await blePeripheralProxy_1.discover(
                characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
                in: MockBleDescriptor.heartRateServiceUUID,
                timeout: .never)
            XCTAssertEqual(characteristic.uuid, MockBleDescriptor.heartRateCharacteristicUUID)
            XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic discovery failed with error: \(error)")
        }
    }
    
    func testDiscoverCharacteristicFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test discovery to fail
        do {
            try await blePeripheralProxy_1.discover(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                in: MockBleDescriptor.deviceInformationServiceUUID,
                timeout: .never)
        } catch BlePeripheralProxyError.peripheralNotConnected {
            XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testDiscoverCharacteristicFailDueToServiceNotFoundAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test discovery to fail
        do {
            try await blePeripheralProxy_1.discover(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                in: MockBleDescriptor.deviceInformationServiceUUID,
                timeout: .never)
        } catch BlePeripheralProxyError.serviceNotFound(let serviceUUID) {
            XCTAssertEqual(serviceUUID, MockBleDescriptor.deviceInformationServiceUUID)
            XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testDiscoverCharacteristicFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock characteristic discovery timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test discovery to fail
        do {
            try await blePeripheralProxy_1.discover(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                in: MockBleDescriptor.deviceInformationServiceUUID,
                timeout: .seconds(2))
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
            XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
    func testDiscoverCharacteristicFailDueToErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock discovery error
        try blePeripheral_1.errorOnDiscoverCharacteristics = MockBleError.mockedError
        // Test discovery to fail
        do {
            try await blePeripheralProxy_1.discover(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                in: MockBleDescriptor.deviceInformationServiceUUID,
                timeout: .seconds(2))
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
            XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertEqual(blePeripheralProxy_1.discoverCharacteristicRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
}
