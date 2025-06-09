//
//  BlePeripheralProxyRSSITests.swift
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

final class BlePeripheralProxyRSSITests: BlueConnectTests {
    
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

// MARK: - RSSI read tests

extension BlePeripheralProxyRSSITests {

    func testPeripheralRSSIUpdate() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test RSSI update on the publisher
        let readExp = expectation(description: "waiting for peripheral RSSI to be read")
        let publisherExp = expectation(description: "waiting for peripheral RSSI update to be signaled by publisher")
        // Test read emit on publisher
        let subscription = blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 >= -90 && $0 <= -50 }
            .sink { _ in publisherExp.fulfill() }
        // Test read on callback
        blePeripheralProxy_1.readRSSI(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let value):
                    XCTAssertGreaterThanOrEqual(value, -90)
                    XCTAssertLessThanOrEqual(value, -50)
                    XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
                    readExp.fulfill()
                case .failure(let error):
                    XCTFail("peripheral RSSI read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }

    func testPeripheralRSSIUpdateFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test RSSI update on the publisher
        let readExp = expectation(description: "waiting for peripheral RSSI read to fail")
        let publisherExp = expectation(description: "waiting for peripheral RSSI update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read emit on publisher
        let subscription = blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
        // Test read on callback
        blePeripheralProxy_1.readRSSI(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
                    readExp.fulfill()
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testPeripheralRSSIUpdateFailDueToReadNotAvailable() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock RSSI error
        try blePeripheral_1.rssiNotAvailable = true
        // Test RSSI update on the publisher
        let readExp = expectation(description: "waiting for peripheral RSSI read to fail")
        let publisherExp = expectation(description: "waiting for peripheral RSSI update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read emit on publisher
        let subscription = blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
        // Test read on callback
        blePeripheralProxy_1.readRSSI(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
                    readExp.fulfill()
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .rssiReadNotAvailable = proxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError 'rssiReadNotAvailable', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testPeripheralRSSIUpdateFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock read timeout
        try blePeripheral_1.delayOnRSSI = .seconds(10)
        // Test RSSI update on the publisher
        let readExp = expectation(description: "waiting for peripheral RSSI read to fail")
        let publisherExp = expectation(description: "waiting for peripheral RSSI update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read emit on publisher
        let subscription = blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
        // Test read on callback
        blePeripheralProxy_1.readRSSI(timeout: .seconds(2)) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
                    readExp.fulfill()
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .rssiReadTimeout = proxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError 'rssiReadNotAvailable', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 4.0)
        subscription.cancel()
    }

    func testPeripheralRSSIUpdateFailDueToError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock read error
        try blePeripheral_1.errorOnRSSI = MockBleError.mockedError
        // Test RSSI update on the publisher
        let readExp = expectation(description: "waiting for peripheral RSSI read to fail")
        let publisherExp = expectation(description: "waiting for peripheral RSSI update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read emit on publisher
        let subscription = blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
        // Test read on callback
        blePeripheralProxy_1.readRSSI(timeout: .seconds(2)) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let mockedError = error as? MockBleError else {
                        XCTFail("peripheral RSSI was expected to fail with MockBleError, got '\(error)' instead")
                        return
                    }
                    guard case .mockedError = mockedError else {
                        XCTFail("peripheral RSSI was expected to fail with MockBleError 'mockedError', got '\(mockedError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
        subscription.cancel()
    }
    
    func testPeripheralRSSIUpdateFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test RSSI update on the publisher
        let expectation = expectation(description: "waiting for peripheral RSSI read to fail")
        // Test read on callback
        blePeripheralProxy_1.readRSSI(timeout: .never) { result in
            switch result {
                case .success:
                    XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .destroyed = proxyError else {
                        XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError 'destroyed', got '\(proxyError)' instead")
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

// MARK: - RSSI read tests (async)

extension BlePeripheralProxyRSSITests {

    func testPeripheralRSSIUpdateAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test RSSI read
        do {
            let value = try await blePeripheralProxy_1.readRSSI(timeout: .never)
            XCTAssertGreaterThanOrEqual(value, -90)
            XCTAssertLessThanOrEqual(value, -50)
            XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral RSSI read failed with error: \(error)")
        }
    }

    func testPeripheralRSSIUpdateFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.readRSSI(timeout: .never)
            XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testPeripheralRSSIUpdateFailDueToReadNotAvailableAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock RSSI value
        try blePeripheral_1.rssiNotAvailable = true
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.readRSSI(timeout: .never)
            XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.rssiReadNotAvailable {
            XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError 'rssiReadNotAvailable', got '\(error)' instead")
        }
    }
    
    func testPeripheralRSSIUpdateFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock read timeout
        try blePeripheral_1.delayOnRSSI = .seconds(10)
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.readRSSI(timeout: .seconds(2))
            XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.rssiReadTimeout {
            XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral RSSI read was expected to fail with BlePeripheralProxyError 'rssiReadTimeout', got '\(error)' instead")
        }
    }

    func testPeripheralRSSIUpdateFailDueToErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock read error
        try blePeripheral_1.errorOnRSSI = MockBleError.mockedError
        // Test read to fail
        do {
            _ = try await blePeripheralProxy_1.readRSSI(timeout: .seconds(2))
            XCTFail("peripheral RSSI read was expected to fail but succeeded instead")
        } catch MockBleError.mockedError {
            XCTAssertEqual(blePeripheralProxy_1.rssiReadRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral RSSI read was expected to fail with MockBleError 'mockedError', got '\(error)' instead")
        }
    }

}

// MARK: - RSSI notify

extension BlePeripheralProxyRSSITests {
    
    func testPeripheralRSSISetNotify() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test RSSI update on the publisher
        let enabledExp = expectation(description: "waiting for peripheral RSSI update to be signaled by publisher")
        enabledExp.expectedFulfillmentCount = 2
        enabledExp.assertForOverFulfill = false
        // Test read emit on publisher
        let subscription1 = blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 >= -90 && $0 <= -50 }
            .sink { _ in enabledExp.fulfill() }
        // Test set notify enabled.
        try blePeripheralProxy_1.setRSSINotify(enabled: true, rate: .seconds(1))
        // Await enabled expectation
        wait(for: [enabledExp], timeout: 4.0)
        subscription1.cancel()
        // Assert boolean status
        XCTAssertTrue(blePeripheralProxy_1.isRSSINotifying)
        // Turn off notification for RSSI
        try blePeripheralProxy_1.setRSSINotify(enabled: false)
        let disabledExp = expectation(description: "waiting for peripheral RSSI update NOT to be signaled by publisher")
        disabledExp.isInverted = true
        // Test read emit on publisher
        let subscription2 = blePeripheralProxy_1.didUpdateRSSIPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 >= -90 && $0 <= -50 }
            .sink { _ in disabledExp.fulfill() }
        // Await enabled expectation
        wait(for: [disabledExp], timeout: 2.0)
        subscription2.cancel()
        // Assert boolean status
        XCTAssertFalse(blePeripheralProxy_1.isRSSINotifying)
    }
    
    func testPeripheralRSSISetNotifyFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test read to fail
        do {
            try blePeripheralProxy_1.setRSSINotify(enabled: true, rate: .seconds(1))
            XCTFail("peripheral RSSI set notify was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            // Assert boolean status
            XCTAssertFalse(blePeripheralProxy_1.isRSSINotifying)
        } catch {
            XCTFail("peripheral RSSI set notify was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
}
