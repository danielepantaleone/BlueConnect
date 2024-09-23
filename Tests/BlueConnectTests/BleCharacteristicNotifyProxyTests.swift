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
import CoreBluetooth
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

// MARK: - Notify tests

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
        bleHeartRateProxy.didUpdateNotificationStatePublisher?
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleHeartRateProxy.didUpdateValuePublisher?
            .receive(on: DispatchQueue.main)
            .sink { _ in valuePublisherExp.fulfill() }
            .store(in: &subscriptions)
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
    }
    
    func testSetNotifyFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic notify enabled
        let notifyExp = expectation(description: "waiting for characteristic set notify to fail")
        let publisherExp = expectation(description: "waiting for characteristic notification state update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test set notify not emitted on publisher
        bleHeartRateProxy.didUpdateNotificationStatePublisher?
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
                    guard case .peripheralNotConnected = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(proxyError.category)' instead")
                        return
                    }
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 2.0)
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
        bleHeartRateProxy.didUpdateNotificationStatePublisher?
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
                    guard case .timeout = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'timeout', got '\(proxyError.category)' instead")
                        return
                    }
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
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
        bleHeartRateProxy.didUpdateNotificationStatePublisher?
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
                    guard case .serviceNotFound = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
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
        bleHeartRateProxy.didUpdateNotificationStatePublisher?
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
                    guard case .characteristicNotFound = proxyError.category else {
                        XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    notifyExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [notifyExp, publisherExp], timeout: 4.0)
    }
    
}

// MARK: - Notify tests (async)

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
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .peripheralNotConnected {
            // NO OP
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'peripheralNotConnected', got '\(error)' instead")
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
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .timeout {
            // NO OP
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'timeout', got '\(error)' instead")
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
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .serviceNotFound {
            // NO OP
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(error)' instead")
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
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {
            // NO OP
        } catch {
            XCTFail("characteristic set notify was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
}
