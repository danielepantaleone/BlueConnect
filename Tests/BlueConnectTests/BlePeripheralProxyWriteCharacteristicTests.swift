//
//  BlePeripheralProxyWriteCharacteristicTests.swift
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

final class BlePeripheralProxyWriteCharacteristicTests: BlueConnectTests {
    
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

// MARK: - Write characteristic tests
    
extension BlePeripheralProxyWriteCharacteristicTests {
    
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
        let subscription = blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
                    writeExp.fulfill()
                case .failure(let error):
                    XCTFail("characteristic write failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .peripheralNotConnected = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .characteristicNotFound(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.serialNumberCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .writeNotSupported(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'writeNotSupported', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 2.0)
        subscription.cancel()
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
        try blePeripheral_1.delayOnWrite = .seconds(10)
        // Test characteristic write
        let writeExp = expectation(description: "waiting for characteristic write to fail")
        let publisherExp = expectation(description: "waiting for characteristic write NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test write ack NOT emitted on publisher
        let subscription = blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard case .writeTimeout(let characteristicUUID) = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'writeTimeout', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
                    XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 4.0)
        subscription.cancel()
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
        let subscription = blePeripheralProxy_1.didWriteValuePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.uuid == MockBleDescriptor.secretCharacteristicUUID }
            .sink { _ in publisherExp.fulfill() }
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
                    guard mockedError == .mockedError else {
                        XCTFail("characteristic write was expected to fail with MockBleError.mockedError, got '\(mockedError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
                    writeExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [writeExp, publisherExp], timeout: 4.0)
        subscription.cancel()
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
        let expectation = expectation(description: "waiting for characteristic write to fail")
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
                    guard case .destroyed = proxyError else {
                        XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'destroyed', got '\(proxyError)' instead")
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

// MARK: - Write characteristic tests (async)
    
extension BlePeripheralProxyWriteCharacteristicTests {
    
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
            XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic write failed with error: \(error)")
        }
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
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {
            XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
        }
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
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
            XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
        }
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
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.writeNotSupported(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.serialNumberCharacteristicUUID)
            XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.serialNumberCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'writeNotSupported', got '\(error)' instead")
        }
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
        try blePeripheral_1.delayOnWrite = .seconds(10)
        // Test characteristic write to fail
        do {
            try await blePeripheralProxy_1.write(
                data: "ABCD".data(using: .utf8)!,
                to: MockBleDescriptor.secretCharacteristicUUID,
                timeout: .seconds(2))
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.writeTimeout(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
            XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'writeTimeout', got '\(error)' instead")
        }
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
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch MockBleError.mockedError {
            XCTAssertEqual(blePeripheralProxy_1.characteristicWriteRegistry.subscriptions(with: MockBleDescriptor.secretCharacteristicUUID), [])
        } catch {
            XCTFail("characteristic write was expected to fail with MockBleError 'mockedError', got '\(error)' instead")
        }
    }
    
    func testWriteCharacteristicFailDueToTaskCancellation() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Discover the service
        discover(serviceUUID: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Discover the characteristic
        discover(characteristicUUID: MockBleDescriptor.secretCharacteristicUUID, in: MockBleDescriptor.customServiceUUID, on: blePeripheralProxy_1)
        // Mock delay
        try blePeripheral_1.delayOnWrite = .seconds(2)
        // Begin test
        let proxy: BlePeripheralProxy! = blePeripheralProxy_1
        let started = XCTestExpectation(description: "Task started")
        let task = Task {
            started.fulfill() // Signal that the task has started
            do {
                try await proxy.write(
                    data: "ABCD".data(using: .utf8)!,
                    to: MockBleDescriptor.secretCharacteristicUUID,
                    timeout: .never)
                XCTFail("Expected task to be cancelled, but it succeeded")
            } catch is CancellationError {
                // Expected path
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
        // Wait for the task to begin.
        await fulfillment(of: [started], timeout: 1.0)
        // Now cancel the task.
        task.cancel()
        // Await the task to ensure cleanup.
        _ = await task.result
    }
    
}

// MARK: - Write without response characteristic tests
    
extension BlePeripheralProxyWriteCharacteristicTests {
    
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
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.peripheralNotConnected {

        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'peripheralNotConnected', got '\(error)' instead")
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
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.characteristicNotFound(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.bufferCharacteristicUUID)
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'characteristicNotFound', got '\(error)' instead")
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
            XCTFail("characteristic write was expected to fail but succeeded instead")
        } catch BlePeripheralProxyError.writeNotSupported(let characteristicUUID) {
            XCTAssertEqual(characteristicUUID, MockBleDescriptor.secretCharacteristicUUID)
        } catch {
            XCTFail("characteristic write was expected to fail with BlePeripheralProxyError 'writeNotSupported', got '\(error)' instead")
        }
    }
    
}
