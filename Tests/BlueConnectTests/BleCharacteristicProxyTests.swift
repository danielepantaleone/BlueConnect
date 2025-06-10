//
//  BleCharacteristicProxyTests.swift
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

final class BleCharacteristicProxyTests: BlueConnectTests {
    
    // MARK: - Properties
    
    var blePeripheralProxy_1: BlePeripheralProxy!
    var bleSerialNumberProxy: MockCharacteristicSerialNumberProxy!
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        blePeripheralProxy_1 = .init(peripheral: try blePeripheral_1)
        bleSerialNumberProxy = .init(peripheralProxy: blePeripheralProxy_1)
    }
    
    override func tearDownWithError() throws {
        bleSerialNumberProxy = nil
        blePeripheralProxy_1 = nil
        try super.tearDownWithError()
    }
    
}

// MARK: - Discover tests

extension BleCharacteristicProxyTests {
    
    func testDiscover() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic discovery
        let expectation = expectation(description: "waiting for characteristic to be discovered")
        bleSerialNumberProxy.discover(timeout: .never) { result in
            switch result {
                case .success(let characteristic):
                    XCTAssertEqual(characteristic.uuid, MockBleDescriptor.serialNumberCharacteristicUUID)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDiscoverFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic discovery failure
        let expectation = expectation(description: "waiting for characteristic NOT to be discovered")
        bleSerialNumberProxy.discover(timeout: .seconds(2)) { result in
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
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }

    func testDiscoverFailDueToDiscoverServiceTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic discovery failure
        let expectation = expectation(description: "waiting for characteristic NOT to be discovered")
        bleSerialNumberProxy.discover(timeout: .seconds(2)) { result in
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
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
    func testDiscoverFailDueToDiscoverCharacteristicTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover characteristic timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic discovery failure
        let expectation = expectation(description: "waiting for characteristic NOT to be discovered")
        bleSerialNumberProxy.discover(timeout: .seconds(2)) { result in
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
                    expectation.fulfill()
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
}

// MARK: - Discover tests (async)

extension BleCharacteristicProxyTests {
    
    func testDiscoverAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic discovery
        do {
            let characteristic = try await bleSerialNumberProxy.discover(timeout: .never)
            XCTAssertEqual(characteristic.uuid, MockBleDescriptor.serialNumberCharacteristicUUID)
        } catch {
            XCTFail("characteristic discovery failed with error: \(error)")
        }
    }
    
    func testDiscoverFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic discovery failure
        do {
            try await bleSerialNumberProxy.discover(timeout: .seconds(2))
            XCTFail("characteristic discovery was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            // NO OP
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testDiscoverFailDueToDiscoverServiceTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic discovery failure
        do {
            try await bleSerialNumberProxy.discover(timeout: .seconds(2))
            XCTFail("characteristic discovery was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.serviceNotFound(let serviceUUID) {
            XCTAssertEqual(serviceUUID, MockBleDescriptor.deviceInformationServiceUUID)
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testDiscoverFailDueToDiscoverCharacteristicTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover characteristic timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic discovery failure
        do {
            try await bleSerialNumberProxy.discover(timeout: .seconds(2))
            XCTFail("characteristic discovery was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
        } catch {
            XCTFail("characteristic discovery was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
}
