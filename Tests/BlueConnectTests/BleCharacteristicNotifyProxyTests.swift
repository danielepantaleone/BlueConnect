//
//  BleCharacteristicNotifyProxyTests.swift
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

final class BleCharacteristicNotifyProxyTests: BlueConnectTests {
    
    // MARK: - Properties
    
    var blePeripheralProxy_1: BlePeripheralProxy!
    var bleHeartRateProxy: MockCharacteristicHeartRateProxy!
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        blePeripheralProxy_1 = .init(peripheral: try blePeripheral_1)
        bleHeartRateProxy = .init(peripheralProxy: blePeripheralProxy_1)
    }
    
    override func tearDownWithError() throws {
        bleHeartRateProxy = nil
        blePeripheralProxy_1 = nil
        try super.tearDownWithError()
    }
    
}

// MARK: - Notification state check characteristic tests

extension BleCharacteristicNotifyProxyTests {
    
    func testIsNotifyingOnCharacteristic() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic notify enabled
        let expectation = expectation(description: "waiting for characteristic notify state to be retrieved")
        // Test notify check on callback
        bleHeartRateProxy.isNotifying(timeout: .never) { result in
            switch result {
                case .success(let enabled):
                    XCTAssertFalse(enabled)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("characteristic notify check failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
    func testIsNotifyingOnCharacteristicFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic notify enabled
        let expectation = expectation(description: "waiting for characteristic notify state not to be retrieved")
        // Test notify check on callback
        bleHeartRateProxy.isNotifying(timeout: .never) { result in
            switch result {
                case .success:
                    XCTFail("characteristic notify check was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
    func testIsNotifyingFailDueToDiscoverServiceTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic notify enabled
        let expectation = expectation(description: "waiting for characteristic notify state not to be retrieved")
        // Test notify check on callback
        bleHeartRateProxy.isNotifying(timeout: .seconds(2)) { result in
            switch result {
                case .success:
                    XCTFail("characteristic notify check was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .serviceNotFound(let serviceUUID) = proxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(serviceUUID, MockBleDescriptor.heartRateServiceUUID)
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
    func testIsNotifyingFailDueToDiscoverCharacteristicTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic notify enabled
        let expectation = expectation(description: "waiting for characteristic notify state not to be retrieved")
        // Test notify check on callback
        bleHeartRateProxy.isNotifying(timeout: .seconds(2)) { result in
            switch result {
                case .success:
                    XCTFail("characteristic notify check was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound(let serviceUUID) = proxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(serviceUUID, MockBleDescriptor.heartRateCharacteristicUUID)
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
        
}

// MARK: - Set notify tests

extension BleCharacteristicNotifyProxyTests {
    
    func testSetNotify() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic notify to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled to be signaled by publisher")
        let valuePublisherExp = expectation(description: "waiting for characteristic value update to be signaled by publisher")
        valuePublisherExp.assertForOverFulfill = false
        valuePublisherExp.expectedFulfillmentCount = 3
        // Test set notify ack emitted on publisher
        let subscription1 = bleHeartRateProxy.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
        let subscription2 = bleHeartRateProxy.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in valuePublisherExp.fulfill() }
        // Test set notify on callback
        bleHeartRateProxy.setNotify(
            enabled: true,
            timeout: .never
        ) { result in
            switch result {
                case .success(let enabled):
                    XCTAssertTrue(enabled)
                    notifyExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic set notify failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp, valuePublisherExp], timeout: 12.0)
        subscription1.cancel()
        subscription2.cancel()
    }
    
    func testSetNotifyFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic set notify to fail")
        let publisherExp = expectation(description: "waiting for characteristic notification state update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test set notify not emitted on publisher
        let subscription = bleHeartRateProxy.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
        bleHeartRateProxy.setNotify(
            enabled: true,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic set notify was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testSetNotifyFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnNotify = .seconds(10)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic set notify to fail")
        let publisherExp = expectation(description: "waiting for characteristic notification state update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test set notify not emitted on publisher
        let subscription = bleHeartRateProxy.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
        bleHeartRateProxy.setNotify(
            enabled: true,
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
                    guard case .notifyTimeout(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'notifyTimeout', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
        subscription.cancel()
    }
    
    func testSetNotifyFailDueToDiscoverServiceTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic set notify to fail")
        let publisherExp = expectation(description: "waiting for characteristic notification state update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test set notify not emitted on publisher
        let subscription = bleHeartRateProxy.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
        bleHeartRateProxy.setNotify(
            enabled: true,
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
                    guard case .serviceNotFound(let serviceUUID) = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(serviceUUID, MockBleDescriptor.heartRateServiceUUID)
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
        subscription.cancel()
    }
    
    func testSetNotifyFailDueToDiscoverCharacteristicTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic set notify to fail")
        let publisherExp = expectation(description: "waiting for characteristic notification state update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test set notify not emitted on publisher
        let subscription = bleHeartRateProxy.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
        bleHeartRateProxy.setNotify(
            enabled: true,
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
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
        subscription.cancel()
    }
    
}

// MARK: - Notification state check characteristic tests /async)

extension BleCharacteristicNotifyProxyTests {
    
    func testIsNotifyingOnCharacteristicAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test notify check
        do {
            let enabled = try await bleHeartRateProxy.isNotifying(timeout: .never)
            XCTAssertFalse(enabled)
        } catch {
            XCTFail("characteristic notify check failed with error: \(error)")
        }
    }
    
    func testIsNotifyingOnCharacteristicFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        do {
            _ = try await bleHeartRateProxy.isNotifying(timeout: .never)
            XCTFail("characteristic notify check was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            // NO OP
        } catch {
            XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testIsNotifyingFailDueToDiscoverServiceTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic notify enabled
        do {
            _ = try await bleHeartRateProxy.isNotifying(timeout: .seconds(2))
            XCTFail("characteristic notify check was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.serviceNotFound(let serviceUUID) {
            XCTAssertEqual(serviceUUID, MockBleDescriptor.heartRateServiceUUID)
        } catch {
            XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testIsNotifyingFailDueToDiscoverCharacteristicTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic notify enabled
        do {
            _ = try await bleHeartRateProxy.isNotifying(timeout: .seconds(2))
            XCTFail("characteristic notify check was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
        } catch {
            XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'characteristicUUID', got '\(error)' instead")
        }
    }
        
}

// MARK: - Set notify tests (async)

extension BleCharacteristicNotifyProxyTests {
    
    func testSetNotifyAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic notify enabled
        do {
            let enabled = try await bleHeartRateProxy.setNotify(
                enabled: true,
                timeout: .never)
            XCTAssertTrue(enabled)
        } catch {
            XCTFail("characteristic set notify failed with error: \(error)")
        }
    }
    
    func testSetNotifyFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic notify enabled
        do {
            _ = try await bleHeartRateProxy.setNotify(enabled: true, timeout: .never)
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            // NO OP
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testSetNotifyFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnNotify = .seconds(10)
        // Test characteristic notify enabled
        do {
            _ = try await bleHeartRateProxy.setNotify(enabled: true, timeout: .seconds(2))
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.notifyTimeout(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'notifyTimeout', got '\(error)' instead")
        }
    }
    
    func testSetNotifyFailDueToDiscoverServiceTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic notify enabled
        do {
            _ = try await bleHeartRateProxy.setNotify(enabled: true, timeout: .seconds(2))
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.serviceNotFound(let serviceUUID) {
            XCTAssertEqual(serviceUUID, MockBleDescriptor.heartRateServiceUUID)
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testSetNotifyFailDueToDiscoverCharacteristicTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock set notify timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic notify enabled
        do {
            _ = try await bleHeartRateProxy.setNotify(enabled: true, timeout: .seconds(2))
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
    func testSetNotifyAndGetIsNotifyingAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Assert initial state
        let isNotifyingInitial = try await bleHeartRateProxy.isNotifying
        XCTAssertFalse(isNotifyingInitial)
        // Test characteristic notify enabled
        do {
            let enabled = try await bleHeartRateProxy.setNotify(
                enabled: true,
                timeout: .never)
            XCTAssertTrue(enabled)
        } catch {
            XCTFail("characteristic set notify failed with error: \(error)")
        }
        // Assert final state
        let isNotifyingFinal = try await bleHeartRateProxy.isNotifying
        XCTAssertTrue(isNotifyingFinal)
        
    }
    
}
