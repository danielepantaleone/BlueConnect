//
//  BlePeripheralProxyNotifyCharacteristicTests.swift
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

final class BlePeripheralProxyNotifyCharacteristicTests: BlueConnectTests {
    
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

// MARK: - Notification state check characteristic tests

extension BlePeripheralProxyNotifyCharacteristicTests {
    
    func testIsNotifyingOnCharacteristic() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic notify enabled
        let expectation = expectation(description: "waiting for characteristic notify state to be retrieved")
        // Test notify check on callback
        blePeripheralProxy_1.isNotifying(
            characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .never
        ) { result in
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
        blePeripheralProxy_1.isNotifying(
            characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .never
        ) { result in
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
    
    func testIsNotifyingOnCharacteristicFailDueToCharacteristicNotFound() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic notify enabled
        let expectation = expectation(description: "waiting for characteristic notify state not to be retrieved")
        // Test notify check on callback
        blePeripheralProxy_1.isNotifying(
            characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic notify check was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
    func testIsNotifyingOnCharacteristicFailDueToOperationNotSupported() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test characteristic notify enabled
        let expectation = expectation(description: "waiting for characteristic notify state not to be retrieved")
        // Test notify check on callback
        blePeripheralProxy_1.isNotifying(
            characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic notify check was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .notifyNotSupported(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'notifyNotSupported', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
}

// MARK: - Set notify characteristic tests

extension BlePeripheralProxyNotifyCharacteristicTests {
    
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
        let subscription1 = blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .filter { $0.enabled }
            .sink { _ in publisherExp.fulfill() }
        let subscription2 = blePeripheralProxy_1.didUpdateValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in valuePublisherExp.fulfill() }
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
                    XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
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
        let subscription = blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
                    notifyExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic set notify failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .notifyNotSupported(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'notifyNotSupported', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        try blePeripheral_1.delayOnNotify = .seconds(10)
        // Test characteristic set notify to fail
        let notifyExp = expectation(description: "waiting for characteristic notify NOT to be enabled")
        let publisherExp = expectation(description: "waiting for characteristic notify enabled NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test notify enabled ack NOT emitted on publisher
        let subscription = blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .notifyTimeout(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'notifyTimeout', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didUpdateNotificationStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.characteristic.uuid == MockBleDescriptor.heartRateCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard mockedError == .mockedError else {
                        XCTFail("characteristic set notify was expected to fail with MockBleError.mockedError, got '\(mockedError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
        subscription.cancel()
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
                    guard case .destroyed = proxyError else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'destroyed', got '\(proxyError)' instead")
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

// MARK: - Notification state check characteristic tests (async)

extension BlePeripheralProxyNotifyCharacteristicTests {
    
    func testIsNotifyingOnCharacteristicAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID, in: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test notify check
        do {
            let enabled = try await blePeripheralProxy_1.isNotifying(
                characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .never)
            XCTAssertFalse(enabled)
        } catch {
            XCTFail("characteristic notify check failed with error: \(error)")
        }
    }
    
    func testIsNotifyingOnCharacteristicFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test notify check
        do {
            _ = try await blePeripheralProxy_1.isNotifying(
                characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .never)
            XCTFail("characteristic notify check was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            // PASS
        } catch {
            XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testIsNotifyingOnCharacteristicFailDueToCharacteristicNotFoundAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID, on: blePeripheralProxy_1)
        // Test notify check
        do {
            _ = try await blePeripheralProxy_1.isNotifying(
                characteristicUUID: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .never)
            XCTFail("characteristic notify check was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
        } catch {
            XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
    func testIsNotifyingOnCharacteristicFailDueToOperationNotSupportedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID, in: MockBleDescriptor.deviceInformationServiceUUID, on: blePeripheralProxy_1)
        // Test notify check on callback
        do {
            _ = try await blePeripheralProxy_1.isNotifying(
                characteristicUUID: MockBleDescriptor.serialNumberCharacteristicUUID,
                timeout: .never)
            XCTFail("characteristic notify check was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.notifyNotSupported(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
        } catch {
            XCTFail("characteristic notify check was expected to fail with BlePeripheralProxyError 'notifyNotSupported', got '\(error)' instead")
        }
    }
    
}

// MARK: - Set notify characteristic tests (async)

extension BlePeripheralProxyNotifyCharacteristicTests {
    
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
            XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic set notify failed with error: \(error)")
        }
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
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
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
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
            XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
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
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.notifyNotSupported(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
            XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'notifyNotSupported', got '\(error)' instead")
        }
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
        try blePeripheral_1.delayOnNotify = .seconds(10)
        // Test characteristic set notify to fail
        do {
            _ = try await blePeripheralProxy_1.setNotify(
                enabled: true,
                for: MockBleDescriptor.heartRateCharacteristicUUID,
                timeout: .seconds(2))
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.notifyTimeout(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.heartRateCharacteristicUUID)
            XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError 'notifyTimeout', got '\(error)' instead")
        }
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
            XCTFail("characteristic set notify was expected to fail but succeeded instead")
        } catch MockBleError.mockedError {
            XCTAssertEqual(blePeripheralProxy_1.characteristicNotifyRegistry.subscriptions(with: MockBleDescriptor.heartRateCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic set notify was expected to fail with MockBleError.mockedError, got '\(error)' instead")
        }
    }
    
}
