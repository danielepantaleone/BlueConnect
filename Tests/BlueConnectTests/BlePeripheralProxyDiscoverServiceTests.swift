//
//  BlePeripheralProxyDiscoverServiceTests.swift
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

final class BlePeripheralProxyDiscoverServiceTests: BlueConnectTests {
    
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

// MARK: - Discover service tests

extension BlePeripheralProxyDiscoverServiceTests {
    
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
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
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

// MARK: - Discover service tests (async)

extension BlePeripheralProxyDiscoverServiceTests {
    
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
    
    func testDiscoverServiceFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discovery timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
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
    
}
