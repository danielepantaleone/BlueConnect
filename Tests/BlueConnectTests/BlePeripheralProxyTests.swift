//
//  BlePeripheralProxyTests.swift
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
import CoreBluetooth
import Foundation
import XCTest

@testable import BlueConnect

final class BlePeripheralProxyTests: BlueConnectTests {
    
    // MARK: - Properties
    
    var blePeripheralProxy_1: BlePeripheralProxy!
    var blePeripheralProxy_2: BlePeripheralProxy!
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        blePeripheralProxy_1 = .init(peripheral: try blePeripheral_1)
        blePeripheralProxy_2 = .init(peripheral: try blePeripheral_2)
    }
    
    override func tearDownWithError() throws {
        blePeripheralProxy_1 = nil
        try super.tearDownWithError()
    }
    
}

// MARK: - Name update tests

extension BlePeripheralProxyTests {
    
    func testPeripheralNameUpdate() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_2)
        // Test name update
        let expectation = expectation(description: "waiting for peripheral name update to be signaled by publisher")
        blePeripheralProxy_2.didUpdateNamePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == "YODA" }
            .sink { _ in expectation.fulfill() }
            .store(in: &subscriptions)
        // Change the name
        try blePeripheral_2.setName("YODA", after: .seconds(2))
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
}

// MARK: - RSSI update tests

extension BlePeripheralProxyTests {
    
    func testPeripheralRSSIUpdate() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test name update
        let expectation = expectation(description: "waiting for peripheral RSSI update to be signaled by publisher")
        blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in expectation.fulfill() }
            .store(in: &subscriptions)
        // Change the name
        try blePeripheral_1.readRSSI(after: .seconds(2))
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
}

// MARK: - Discover service tests

extension BlePeripheralProxyTests {
    
    func testDiscoverService() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test service discovery
        let discoveryExp = expectation(description: "waiting for service to be discovered")
        let publisherExp = expectation(description: "waiting for service discovery to be signaled by publisher")
        // Test discovery emit on publisher
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .filter { services in services.contains(where: { $0.uuid == MockBleDescriptor.deviceInformationServiceUUID })}
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            serviceUUID: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let service):
                    XCTAssertEqual(service.uuid, MockBleDescriptor.deviceInformationServiceUUID)
                    XCTAssertEqual(try? blePeripheral_1.services?.count, 1)
                    XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.deviceInformationServiceUUID])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("service discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
    }
    
    func testDiscoverServiceAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test service discovery
        do {
            let service = try await blePeripheralProxy_1.discover(
                serviceUUID: MockBleDescriptor.deviceInformationServiceUUID,
                timeout: .never)
            XCTAssertEqual(service.uuid, MockBleDescriptor.deviceInformationServiceUUID)
            XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.deviceInformationServiceUUID])
        } catch {
            XCTFail("service discovery failed with error: \(error)")
        }
    }
    
    func testDiscoverServiceWithServiceAlreadyDiscovered() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test second discovery
        let discoveryExp = expectation(description: "waiting for service discovery even if already discovered")
        let publisherExp = expectation(description: "waiting for service discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .filter { services in services.contains(where: { $0.uuid == MockBleDescriptor.deviceInformationServiceUUID })}
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            serviceUUID: MockBleDescriptor.deviceInformationServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let service):
                    XCTAssertEqual(service.uuid, MockBleDescriptor.deviceInformationServiceUUID)
                    XCTAssertEqual(try? blePeripheral_1.services?.count, 1)
                    XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.deviceInformationServiceUUID])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("service discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
    }
    
    func testDiscoverServiceWithMixedServiceDiscovery() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test second discovery
        let discoveryExp = expectation(description: "waiting for service discovery even if already discovered")
        let publisherExp = expectation(description: "waiting for service discovery to be signaled by publisher")
        publisherExp.expectedFulfillmentCount = 2
        // Test publisher not called
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.forEach { _ in publisherExp.fulfill() } }
            .store(in: &subscriptions)
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            serviceUUID: MockBleDescriptor.heartRateServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let service):
                    XCTAssertEqual(service.uuid, MockBleDescriptor.heartRateServiceUUID)
                    XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.heartRateServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.heartRateServiceUUID])
                    XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.deviceInformationServiceUUID])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("service discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
    }
    
    func testDiscoverServices() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test services discovery
        let expectation = expectation(description: "waiting for services discovery to be signaled by publisher")
        expectation.expectedFulfillmentCount = 3
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.forEach { _ in expectation.fulfill() } }
            .store(in: &subscriptions)
        blePeripheralProxy_1.discover(serviceUUIDs: [
            MockBleDescriptor.deviceInformationServiceUUID,
            MockBleDescriptor.batteryServiceUUID,
            MockBleDescriptor.customServiceUUID
        ])
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDiscoverServicesWithNoArguments() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test services discovery
        let expectation = expectation(description: "waiting for services discovery to be signaled by publisher")
        expectation.expectedFulfillmentCount = 4
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.forEach { _ in expectation.fulfill() } }
            .store(in: &subscriptions)
        blePeripheralProxy_1.discover(serviceUUIDs: nil)
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDiscoverServiceFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test service discovery
        let discoveryExp = expectation(description: "waiting for service discovery to fail")
        let publisherExp = expectation(description: "waiting for service discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            serviceUUID: MockBleDescriptor.heartRateServiceUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("service discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError.category else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.heartRateServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.heartRateServiceUUID])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
    }
    
    func testDiscoverServiceFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test discovery to fail
        do {
            try await blePeripheralProxy_1.discover(
                serviceUUID: MockBleDescriptor.heartRateServiceUUID,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .peripheralNotConnected {
            XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.heartRateServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.heartRateServiceUUID])
        } catch {
            XCTFail("service discovery was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testDiscoverServiceFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test service discovery
        let discoveryExp = expectation(description: "waiting for service discovery to fail")
        let publisherExp = expectation(description: "waiting for service discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Mock discovery timeout
        try blePeripheral_1.timeoutOnDiscoverServices = true
        // Test publisher not called
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            serviceUUID: MockBleDescriptor.heartRateServiceUUID,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("service discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .serviceNotFound = proxyError.category else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.heartRateServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.heartRateServiceUUID])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 4.0)
    }
    
    func testDiscoverServiceFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discovery timeout
        try blePeripheral_1.timeoutOnDiscoverServices = true
        // Test timeout
        do {
            try await blePeripheralProxy_1.discover(
                serviceUUID: MockBleDescriptor.heartRateServiceUUID,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .serviceNotFound {
            XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.heartRateServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.heartRateServiceUUID])
        } catch {
            XCTFail("service discovery was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testDiscoverServiceFailDueToError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test service discovery
        let discoveryExp = expectation(description: "waiting for service discovery to fail")
        let publisherExp = expectation(description: "waiting for service discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Mock discovery error
        try blePeripheral_1.errorOnDiscoverServices = MockBleError.mockedError
        // Test publisher not called
        blePeripheralProxy_1.didDiscoverServicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test discovery on callback
        blePeripheralProxy_1.discover(
            serviceUUID: MockBleDescriptor.heartRateServiceUUID,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("service discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .serviceNotFound = proxyError.category else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.heartRateServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.heartRateServiceUUID])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 4.0)
    }
    
    func testDiscoverServiceFailDueToErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discovery error
        try blePeripheral_1.errorOnDiscoverServices = MockBleError.mockedError
        // Test discovery fail
        do {
            try await blePeripheralProxy_1.discover(
                serviceUUID: MockBleDescriptor.heartRateServiceUUID,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .serviceNotFound {
            XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.heartRateServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.discoverServiceTimers[MockBleDescriptor.heartRateServiceUUID])
        } catch {
            XCTFail("service discovery was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testDiscoverServiceFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discovery delay
        try blePeripheral_1.delayOnDiscoverServices = .seconds(2)
        // Test discovery failure
        let expectation = expectation(description: "waiting for service discovery to fail")
        blePeripheralProxy_1.discover(
            serviceUUID: MockBleDescriptor.heartRateServiceUUID,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("service discovery was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .destroyed = proxyError.category else {
                        XCTFail("service discovery was expected to fail with BlePeripheralProxyError category 'destroyed', got '\(proxyError.category)' instead")
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

// MARK: - Discover characteristic tests

extension BlePeripheralProxyTests {
    
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.heartRateServiceUUID && $1.contains(where: { $0.uuid == MockBleDescriptor.heartRateCharacteristicUUID })}
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
                    XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.heartRateCharacteristicUUID])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
    }
    
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
            XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.heartRateCharacteristicUUID])
        } catch {
            XCTFail("characteristic discovery failed with error: \(error)")
        }
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.deviceInformationServiceUUID && $1.contains(where: { $0.uuid == MockBleDescriptor.serialNumberCharacteristicUUID })}
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
                    XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.deviceInformationServiceUUID && $1.contains(where: { $0.uuid == MockBleDescriptor.firmwareRevisionCharacteristicUUID })}
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
            .store(in: &subscriptions)
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
                    XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.firmwareRevisionCharacteristicUUID])
                    discoveryExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in expectation.fulfill() } }
            .store(in: &subscriptions)
        blePeripheralProxy_1.discover(
            characteristicUUIDs: [
                MockBleDescriptor.serialNumberCharacteristicUUID,
                MockBleDescriptor.firmwareRevisionCharacteristicUUID
            ],
            in: MockBleDescriptor.deviceInformationServiceUUID)
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID))
        XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.hardwareRevisionCharacteristicUUID))
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in expectation.fulfill() } }
            .store(in: &subscriptions)
        blePeripheralProxy_1.discover(
            characteristicUUIDs: nil,
            in: MockBleDescriptor.deviceInformationServiceUUID)
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.firmwareRevisionCharacteristicUUID))
        XCTAssertNotNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.hardwareRevisionCharacteristicUUID))
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
            .store(in: &subscriptions)
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
                    guard case .peripheralNotConnected = proxyError.category else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
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
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .peripheralNotConnected {
            XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(error)' instead")
        }
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
            .store(in: &subscriptions)
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
                    guard case .serviceNotFound = proxyError.category else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 2.0)
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
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .serviceNotFound {
            XCTAssertNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testDiscoverCharacteristicFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock characteristic discovery timeout
        try blePeripheral_1.timeoutOnDiscoverCharacteristics = true
        // Test characteristic discovery
        let discoveryExp = expectation(description: "waiting for characteristic discovery to fail")
        let publisherExp = expectation(description: "waiting for characteristic discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test publisher not called
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
            .store(in: &subscriptions)
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
                    guard case .characteristicNotFound = proxyError.category else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 4.0)
    }
    
    func testDiscoverCharacteristicFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Mock characteristic discovery timeout
        try blePeripheral_1.timeoutOnDiscoverCharacteristics = true
        // Test discovery to fail
        do {
            try await blePeripheralProxy_1.discover(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                in: MockBleDescriptor.deviceInformationServiceUUID,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {
            XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
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
        blePeripheralProxy_1.didDiscoverCharacteristicsPublisher
            .receive(on: DispatchQueue.main)
            .sink { $0.characteristics.forEach { _ in publisherExp.fulfill() } }
            .store(in: &subscriptions)
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
                    guard case .characteristicNotFound = proxyError.category else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
                    XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
                    XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    discoveryExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [discoveryExp, publisherExp], timeout: 4.0)
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
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {
            XCTAssertNotNil(blePeripheralProxy_1.getService(MockBleDescriptor.deviceInformationServiceUUID))
            XCTAssertNil(blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.serialNumberCharacteristicUUID))
            XCTAssertNil(blePeripheralProxy_1.discoverCharacteristicTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
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
                    guard case .destroyed = proxyError.category else {
                        XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError category 'destroyed', got '\(proxyError.category)' instead")
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

// MARK: - Read characteristic tests
    
extension BlePeripheralProxyTests {
        
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
            policy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let serialNumber = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID]
                    XCTAssertEqual(serialNumber, "12345678")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    readExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
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
                policy: .never,
                timeout: .never)
            let serialNumber = String(data: data, encoding: .utf8)
            let record = blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID]
            XCTAssertEqual(serialNumber, "12345678")
            XCTAssertEqual(record?.data, data)
            XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic read failed with error: \(error)")
        }
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
                policy: .never,
                timeout: .never
            ) { [weak self] result in
                guard let self else { return }
                switch result {
                    case .success(let data):
                        let serialNumber = String(data: data, encoding: .utf8)
                        let record = blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID]
                        XCTAssertEqual(serialNumber, "12345678")
                        XCTAssertEqual(record?.data, data)
                        XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
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
            policy: .always,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let firmwareRevision = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.firmwareRevisionCharacteristicUUID]
                    XCTAssertEqual(firmwareRevision, "1.0.7")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.firmwareRevisionCharacteristicUUID])
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
            policy: .timeSensitive(.seconds(4)),
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let firmwareRevision = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.firmwareRevisionCharacteristicUUID]
                    XCTAssertEqual(firmwareRevision, "1.0.7")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.firmwareRevisionCharacteristicUUID])
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
            policy: .timeSensitive(.seconds(2)),
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    let firmwareRevision = String(data: data, encoding: .utf8)
                    let record = blePeripheralProxy_1.cache[MockBleDescriptor.firmwareRevisionCharacteristicUUID]
                    XCTAssertEqual(firmwareRevision, "2.0.0")
                    XCTAssertEqual(record?.data, data)
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.firmwareRevisionCharacteristicUUID])
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
            policy: .never,
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
                    guard case .peripheralNotConnected = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
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
                policy: .never,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .peripheralNotConnected {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(error)' instead")
        }
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
            policy: .never,
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
                    guard case .characteristicNotFound = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
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
                policy: .never,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
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
            policy: .never,
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
                    guard case .operationNotSupported = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'operationNotSupported', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.secretCharacteristicUUID])
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.secretCharacteristicUUID])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
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
                policy: .never,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .operationNotSupported {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.secretCharacteristicUUID])
            XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.secretCharacteristicUUID])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'operationNotSupported', got '\(error)' instead")
        }
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
        try blePeripheral_1.timeoutOnRead = true
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
            policy: .never,
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
                    guard case .timeout = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'timeout', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
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
        try blePeripheral_1.timeoutOnRead = true
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.read(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                policy: .never,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .timeout {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'timeout', got '\(error)' instead")
        }
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
            policy: .never,
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
                        XCTFail("characteristic read was expected to fail with MockBleError category 'mockedError', got '\(mockedError)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
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
                policy: .never,
                timeout: .never)
        } catch MockBleError.mockedError {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic read was expected to fail with MockBleError category 'mockedError', got '\(error)' instead")
        }
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
            policy: .never,
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
                    guard case .characteristicDataIsNil = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'characteristicDataIsNil', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.secretCharacteristicUUID])
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.secretCharacteristicUUID])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
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
                policy: .never,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicDataIsNil {
            XCTAssertNil(blePeripheralProxy_1.cache[MockBleDescriptor.serialNumberCharacteristicUUID])
            XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'characteristicDataIsNil', got '\(error)' instead")
        }
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
            policy: .never,
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
                    guard case .destroyed = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'destroyed', got '\(proxyError.category)' instead")
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

// MARK: - Write characteristic tests
    
extension BlePeripheralProxyTests {
    
    func testWriteCharacteristic() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic to be written")
        let publisherExp = expectation(description: "waiting for characteristic write to be signaled by publisher")
        // Test write ack emit on publisher
        blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test write on callback
        blePeripheralProxy_1.write(
            data: "ABCD".data(using: .utf8)!,
            to: MockBleDescriptor.secretCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.secretCharacteristicUUID)
                    let secret = characteristic?.value.map { String(data: $0, encoding: .utf8) }
                    XCTAssertEqual(secret, "ABCD")
                    XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
                    writeExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic write failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
    }
    
    func testWriteCharacteristicAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write
        do {
            try await blePeripheralProxy_1.write(
                data: "ABCD".data(using: .utf8)!,
                to: MockBleDescriptor.secretCharacteristicUUID,
                timeout: .never)
            let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.secretCharacteristicUUID)
            let secret = characteristic?.value.map { String(data: $0, encoding: .utf8) }
            XCTAssertEqual(secret, "ABCD")
            XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
        } catch {
            XCTFail("characteristic write failed with error: \(error)")
        }
    }
    
    func testWriteCharacteristicFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack NOT emitted on publisher
        blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test write to fail
        blePeripheralProxy_1.write(
            data: "ABCD".data(using: .utf8)!,
            to: MockBleDescriptor.secretCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError.category else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
    }
    
    func testWriteCharacteristicFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test characteristic write to fail
        do {
            try await blePeripheralProxy_1.write(
                data: "ABCD".data(using: .utf8)!,
                to: MockBleDescriptor.secretCharacteristicUUID,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .peripheralNotConnected {
            XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicFailDueToCharacteristicNotFound() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack NOT emitted on publisher
        blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test write to fail
        blePeripheralProxy_1.write(
            data: "ABCD".data(using: .utf8)!,
            to: MockBleDescriptor.secretCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound = proxyError.category else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
    }
    
    func testWriteCharacteristicFailDueToCharacteristicNotFoundAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write to fail
        do {
            try await blePeripheralProxy_1.write(
                data: "ABCD".data(using: .utf8)!,
                to: MockBleDescriptor.secretCharacteristicUUID,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {
            XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicFailDueToOperationNotSupported() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack NOT emitted on publisher
        blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test write to fail
        blePeripheralProxy_1.write(
            data: "ABCD".data(using: .utf8)!,
            to: MockBleDescriptor.serialNumberCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .operationNotSupported = proxyError.category else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'operationNotSupported', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
    }
    
    func testWriteCharacteristicFailDueToOperationNotSupportedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write to fail
        do {
            try await blePeripheralProxy_1.write(
                data: "ABCD".data(using: .utf8)!,
                to: MockBleDescriptor.serialNumberCharacteristicUUID,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .operationNotSupported {
            XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'operationNotSupported', got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Mock write timeout
        try blePeripheral_1.timeoutOnWrite = true
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack NOT emitted on publisher
        blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test write to fail
        blePeripheralProxy_1.write(
            data: "ABCD".data(using: .utf8)!,
            to: MockBleDescriptor.secretCharacteristicUUID,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .timeout = proxyError.category else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'timeout', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 4.0)
    }
    
    func testWriteCharacteristicFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Mock write timeout
        try blePeripheral_1.timeoutOnWrite = true
        // Test characteristic write to fail
        do {
            try await blePeripheralProxy_1.write(
                data: "ABCD".data(using: .utf8)!,
                to: MockBleDescriptor.secretCharacteristicUUID,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .timeout {
            XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'timeout', got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicFailDueToError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Mock write error
        try blePeripheral_1.errorOnWrite = MockBleError.mockedError
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack NOT emitted on publisher
        blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test write to fail
        blePeripheralProxy_1.write(
            data: "ABCD".data(using: .utf8)!,
            to: MockBleDescriptor.secretCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let mockedError = error as? MockBleError else {
                        XCTFail("characteristic write was expected to fail with MockBleError.mockedError, got '\(error)' instead")
                        return
                    }
                    guard mockedError == MockBleError.mockedError else {
                        XCTFail("characteristic write was expected to fail with MockBleError.mockedError, got '\(mockedError)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 4.0)
    }
    
    func testWriteCharacteristicFailDueToErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Mock write error
        try blePeripheral_1.errorOnWrite = MockBleError.mockedError
        // Test characteristic write to fail
        do {
            try await blePeripheralProxy_1.write(
                data: "ABCD".data(using: .utf8)!,
                to: MockBleDescriptor.secretCharacteristicUUID,
                timeout: .never)
        } catch MockBleError.mockedError {
            XCTAssertNil(blePeripheralProxy_1.characteristicWriteTimers[MockBleDescriptor.secretCharacteristicUUID])
        } catch {
            XCTFail("characteristic write was expected to fail with MockBleError.mockedError, got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Mock write delay
        try blePeripheral_1.delayOnWrite = .seconds(2)
        // Test write to fail
        let expectation = expectation(description: "waiting for characteristic read to fail")
        blePeripheralProxy_1.write(
            data: "ABCD".data(using: .utf8)!,
            to: MockBleDescriptor.secretCharacteristicUUID,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .destroyed = proxyError.category else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'destroyed', got '\(proxyError.category)' instead")
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

// MARK: - Write without response characteristic tests
    
extension BlePeripheralProxyTests {
    
    func testWriteCharacteristicWithoutResponse() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.bufferCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write
        do {
            try blePeripheralProxy_1.writeWithoutResponse(data: Data([0x00, 0x01]), to: MockBleDescriptor.bufferCharacteristicUUID)
        } catch {
            XCTFail("characteristic write without response failed with error: \(error)")
        }
    }
    
    func testWriteCharacteristicWithoutResponseFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.bufferCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test characteristic write
        do {
            try blePeripheralProxy_1.writeWithoutResponse(data: Data([0x00, 0x01]), to: MockBleDescriptor.bufferCharacteristicUUID)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .peripheralNotConnected {

        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicWithoutResponseFailDueToCharacteristicNotFound() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write
        do {
            try blePeripheralProxy_1.writeWithoutResponse(data: Data([0x00, 0x01]), to: MockBleDescriptor.bufferCharacteristicUUID)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {

        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicWithoutResponseFailDueToOperationNotSupported() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic write
        do {
            try blePeripheralProxy_1.writeWithoutResponse(data: Data([0x00, 0x01]), to: MockBleDescriptor.secretCharacteristicUUID)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .operationNotSupported {

        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError category 'operationNotSupported', got '\(error)' instead")
        }
    }
    
}

// MARK: - Notify characteristic tests

extension BlePeripheralProxyTests {
    
    func testSetNotifyOnCharacteristic() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic notify to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled to be signaled by publisher")
        let valuePublisherExp = expectation(description: "waiting for characteristic value update to be signaled by publisher")
        valuePublisherExp.assertForOverFulfill = false
        valuePublisherExp.expectedFulfillmentCount = 3
        // Test set notify ack emitted on publisher
        blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .filter { $0.enabled }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in valuePublisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test set notify on callback
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let enabled):
                    let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.heartRateCharacteristicUUID)
                    XCTAssertTrue(enabled)
                    XCTAssertEqual(enabled, characteristic?.isNotifying)
                    XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
                    notifyExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic set notify failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp, valuePublisherExp], timeout: 12.0)
    }
    
    func testSetNotifyOnCharacteristicAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic notify enabled
        do {
            let enabled = try await blePeripheralProxy_1.setNotify(
                enabled: true,
                for: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .never)
            let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.heartRateCharacteristicUUID)
            XCTAssertTrue(enabled)
            XCTAssertEqual(enabled, characteristic?.isNotifying)
            XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
        } catch {
            XCTFail("characteristic set notify failed with error: \(error)")
        }
    }
    
    func testSetNotifyOnCharacteristicWithNotifyAlreadyEnabled() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Enable notify
        setNotify(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, enabled: true, on: blePeripheralProxy_1)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic notify to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled NOT to be signaled by publisher because already enabled")
        publisherExp.isInverted = true
        // Test set notify ack emitted on publisher
        blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test set notify on callback
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let enabled):
                    let characteristic = blePeripheralProxy_1.getCharacteristic(MockBleDescriptor.heartRateCharacteristicUUID)
                    XCTAssertTrue(enabled)
                    XCTAssertEqual(enabled, characteristic?.isNotifying)
                    XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
                    notifyExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic set notify failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
    }
    
    func testSetNotifyOnCharacteristicFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test characteristic set notify to fail
        let notifyExp = expectation(description: "waiting for characteristic notify NOT to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test notify enabled ack NOT emitted on publisher
        blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test set notify to fail
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic set notify was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
    }
    
    func testSetNotifyOnCharacteristicFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Disconnect the peripheral
        disconnect(peripheral: try blePeripheral_1)
        // Test characteristic set notify to fail
        do {
            _ = try await blePeripheralProxy_1.setNotify(
                enabled: true,
                for: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .peripheralNotConnected {
            XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testSetNotifyOnCharacteristicFailDueToCharacteristicNotFound() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic set notify
        let notifyExp = expectation(description: "waiting for characteristic notify NOT to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test notify enabled ack NOT emitted on publisher
        blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test set notify to fail
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic set notify was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
    }
    
    func testSetNotifyOnCharacteristicFailDueToCharacteristicNotFoundAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic set notify to fail
        do {
            _ = try await blePeripheralProxy_1.setNotify(
                enabled: true,
                for: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .never)
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {
            XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
    func testSetNotifyOnCharacteristicFailDueToOperationNotSupported() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic set notify to fail
        let notifyExp = expectation(description: "waiting for characteristic notify NOT to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test notify enabled ack NOT emitted on publisher
        blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test set notify to fail
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.serialNumberCharacteristicUUID,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic set notify was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .operationNotSupported = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'operationNotSupported', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
    }
    
    func testSetNotifyOnCharacteristicFailDueToOperationNotSupportedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic set notify to fail
        do {
            _ = try await blePeripheralProxy_1.setNotify(
                enabled: true,
                for: MockBleDescriptor.serialNumberCharacteristicUUID,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .operationNotSupported {
            XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'operationNotSupported', got '\(error)' instead")
        }
    }
    
    func testSetNotifyOnCharacteristicFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Mock set notify timeout
        try blePeripheral_1.timeoutOnNotify = true
        // Test characteristic set notify to fail
        let notifyExp = expectation(description: "waiting for characteristic notify NOT to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test notify enabled ack NOT emitted on publisher
        blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test set notify to fail
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic set notify was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .timeout = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'timeout', got '\(proxyError.category)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
    }
    
    func testSetNotifyOnCharacteristicFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Mock set notify timeout
        try blePeripheral_1.timeoutOnNotify = true
        // Test characteristic set notify to fail
        do {
            _ = try await blePeripheralProxy_1.setNotify(
                enabled: true,
                for: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .seconds(2))
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .timeout {
            XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'timeout', got '\(error)' instead")
        }
    }
    
    func testSetNotifyOnCharacteristicFailDueToError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Mock set notify error
        try blePeripheral_1.errorOnNotify = MockBleError.mockedError
        // Test characteristic set notify to fail
        let notifyExp = expectation(description: "waiting for characteristic notify NOT to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test notify enabled ack NOT emitted on publisher
        blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test set notify to fail
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .seconds(2)
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("characteristic set notify was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let mockedError = error as? MockBleError else {
                        XCTFail("characteristic set notify was expected to fail with MockBleError.mockedError, got '\(error)' instead")
                        return
                    }
                    guard mockedError == MockBleError.mockedError else {
                        XCTFail("characteristic set notify was expected to fail with MockBleError.mockedError, got '\(mockedError)' instead")
                        return
                    }
                    XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
    }
    
    func testSetNotifyOnCharacteristicFailDueToErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Mock set notify error
        try blePeripheral_1.errorOnNotify = MockBleError.mockedError
        // Test characteristic set notify to fail
        do {
            _ = try await blePeripheralProxy_1.setNotify(
                enabled: true,
                for: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .seconds(2))
        } catch MockBleError.mockedError {
            XCTAssertNil(blePeripheralProxy_1.characteristicNotifyTimers[MockBleDescriptor.heartRateCharacteristicUUID])
        } catch {
            XCTFail("characteristic set notify was expected to fail with MockBleError.mockedError, got '\(error)' instead")
        }
    }
    
    func testSetNotifyOnCharacteristicFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Mock set notify delay
        try blePeripheral_1.delayOnNotify = .seconds(2)
        // Test set notify to fail
        let expectation = expectation(description: "waiting for characteristic set notify to fail")
        blePeripheralProxy_1.setNotify(
            enabled: true,
            for: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .seconds(2)
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic set notify was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .destroyed = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'destroyed', got '\(proxyError.category)' instead")
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
