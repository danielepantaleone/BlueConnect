//
//  BleCharacteristicWriteWithoutResponseProxyTests.swift
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

final class BleCharacteristicWriteWithoutResponseProxyTests: BlueConnectTests {
    
    // MARK: - Properties
    
    var blePeripheralProxy_1: BlePeripheralProxy!
    var bleBufferProxy: MockCharacteristicBufferProxy!
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        blePeripheralProxy_1 = .init(peripheral: try blePeripheral_1)
        bleBufferProxy = .init(peripheralProxy: blePeripheralProxy_1)
    }
    
    override func tearDownWithError() throws {
        bleBufferProxy = nil
        blePeripheralProxy_1 = nil
        try super.tearDownWithError()
    }
    
}


// MARK: - Write without response tests

extension BleCharacteristicWriteWithoutResponseProxyTests {
    
    func testWriteWithoutResponse() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic to be written")
        // Test write ack on callback
        bleBufferProxy.writeWithoutResponse (
            value: Data([0x00, 0x01, 0x02, 0x03]),
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    writeExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic write failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [writeExp], timeout: 2.0)
    }
    
    func testWriteWithoutResponseFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        bleBufferProxy.writeWithoutResponse (
            value: Data([0x00, 0x01, 0x02, 0x03]),
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
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp], timeout: 6.0)
    }
    
    func testWriteWithoutResponseFailDueToDiscoverServiceTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        bleBufferProxy.writeWithoutResponse (
            value: Data([0x00, 0x01, 0x02, 0x03]),
            timeout: .seconds(2)
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .serviceNotFound = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(proxyError)' instead")
                        return
                    }
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp,], timeout: 4.0)
    }
    
    func testWriteWithoutResponseFailDueToDiscoverCharacteristicTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover characteristic timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        bleBufferProxy.writeWithoutResponse (
            value: Data([0x00, 0x01, 0x02, 0x03]),
            timeout: .seconds(2)
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .characteristicNotFound = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp], timeout: 4.0)
    }
    
}

// MARK: - Write without response tests (async)

extension BleCharacteristicWriteWithoutResponseProxyTests {
    
    func testWriteWithoutResponseAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic write
        do {
            try await bleBufferProxy.writeWithoutResponse (
                value: Data([0x00, 0x01, 0x02, 0x03]),
                timeout: .never)
        } catch {
            XCTFail("characteristic write failed with error: \(error)")
        }
    }
    
    func testWriteWithoutResponseFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic write
        do {
            try await bleBufferProxy.writeWithoutResponse (
                value: Data([0x00, 0x01, 0x02, 0x03]),
                timeout: .never)
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            // NO OP
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testWriteWithoutResponseFailDueToDiscoverServiceTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic write
        do {
            try await bleBufferProxy.writeWithoutResponse (
                value: Data([0x00, 0x01, 0x02, 0x03]),
                timeout: .seconds(2))
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.serviceNotFound {
            // NO OP
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testWriteWithoutResponseFailDueToDiscoverCharacteristicTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic write
        do {
            try await bleBufferProxy.writeWithoutResponse (
                value: Data([0x00, 0x01, 0x02, 0x03]),
                timeout: .seconds(2))
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound {
            // NO OP
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
}
