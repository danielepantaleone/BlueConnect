//
//  BleCharacteristicWriteProxyTests.swift
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

final class BleCharacteristicWriteProxyTests: BlueConnectTests {
    
    // MARK: - Properties
    
    var blePeripheralProxy_1: BlePeripheralProxy!
    var bleSecretProxy: MockCharacteristicSecretProxy!
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        blePeripheralProxy_1 = .init(peripheral: try blePeripheral_1)
        bleSecretProxy = .init(peripheralProxy: blePeripheralProxy_1)
    }
    
    override func tearDownWithError() throws {
        bleSecretProxy = nil
        blePeripheralProxy_1 = nil
        try super.tearDownWithError()
    }
    
}

// MARK: - Write tests

extension BleCharacteristicWriteProxyTests {
    
    func testWrite() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic to be written")
        let publisherExp = expectation(description: "waiting for characteristic write ack to be signaled by publisher")
        // Test write ack emit on publisher
        bleSecretProxy.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test write ack on callback
        bleSecretProxy.write(
            value: "AAAA",
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
        wait(for: [writeExp, publisherExp], timeout: 2.0)
    }
    
    func testWriteFailDueToPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write ack NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack not emitted on publisher
        bleSecretProxy.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSecretProxy.write(
            value: "AAAA",
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
        wait(for: [writeExp, publisherExp], timeout: 6.0)
    }
    
    func testWriteFailDueToEncodingError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock encoding error
        bleSecretProxy.encodingError = MockBleError.mockedError
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write ack NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack not emitted on publisher
        bleSecretProxy.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSecretProxy.write(
            value: "AAAA",
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic write was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCharacteristicProxyError else {
                        XCTFail("characteristic write was expected to fail with BleCharacteristicProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .encodingError(let characteristicUUID, _) = proxyError else {
                        XCTFail("characteristic write was expected to fail with BleCharacteristicProxyError 'encodingError', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
    }
    
    func testWriteFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock write timeout
        try blePeripheral_1.delayOnWrite = .seconds(10)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write ack NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack not emitted on publisher
        bleSecretProxy.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSecretProxy.write(
            value: "AAAA",
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
                    guard case .writeTimeout(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'writeTimeout', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 4.0)
    }
    
    func testWriteFailDueToDiscoverServiceTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write ack NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack not emitted on publisher
        bleSecretProxy.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSecretProxy.write(
            value: "AAAA",
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
                    guard case .serviceNotFound(let serviceUUID) = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(serviceUUID, MockBleDescriptor.customServiceUUID)
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 4.0)
    }
    
    func testWriteFailDueToDiscoverCharacteristicTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover characteristic timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write ack NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack not emitted on publisher
        bleSecretProxy.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSecretProxy.write(
            value: "AAAA",
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
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 4.0)
    }
    
}

// MARK: - Write tests (async)

extension BleCharacteristicWriteProxyTests {
    
    func testWriteAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic write
        do {
            try await bleSecretProxy.write(value: "AAAA", timeout: .never)
        } catch {
            XCTFail("characteristic write failed with error: \(error)")
        }
    }
    
    func testWriteFailDueToPeripheralDisconnectedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test characteristic write
        do {
            try await bleSecretProxy.write(value: "AAAA", timeout: .never)
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            // NO OP
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
    }
    
    func testWriteFailDueToEncodingErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock encoding error
        bleSecretProxy.encodingError = MockBleError.mockedError
        // Test characteristic write
        do {
            try await bleSecretProxy.write(value: "AAAA", timeout: .never)
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BleCharacteristicProxyError.encodingError(let characteristicUUID, _) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
        } catch {
            XCTFail("characteristic write was expected to fail with BleCharacteristicProxyError 'encodingError', got '\(error)' instead")
        }
    }
    
    func testWriteFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock write timeout
        try blePeripheral_1.delayOnWrite = .seconds(10)
        // Test characteristic write
        do {
            try await bleSecretProxy.write(value: "AAAA", timeout: .seconds(2))
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.writeTimeout(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'writeTimeout', got '\(error)' instead")
        }
    }
    
    func testWriteFailDueToDiscoverServiceTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic write
        do {
            try await bleSecretProxy.write(value: "AAAA", timeout: .seconds(2))
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.serviceNotFound(let serviceUUID) {
            XCTAssertEqual(serviceUUID, MockBleDescriptor.customServiceUUID)
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testWriteFailDueToDiscoverCharacteristicTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover characteristic timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic write
        do {
            try await bleSecretProxy.write(value: "AAAA", timeout: .seconds(2))
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
}
