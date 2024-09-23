//
//  BleCharacteristicReadProxyTests.swift
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

final class BleCharacteristicReadProxyTests: BlueConnectTests {
    
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

// MARK: - Read tests

extension BleCharacteristicReadProxyTests {
    
    func testRead() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic to be read")
        let publisherExp = expectation(description: "waiting for characteristic update to be signaled by publisher")
        // Test read emit on publisher
        bleSerialNumberProxy.didUpdateValuePublisher?
            .receive(on: DispatchQueue.main)
            .filter { $0 == "12345678" }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test read on callback
        bleSerialNumberProxy.read(
            cachePolicy: .never,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let serialNumber):
                    XCTAssertEqual(serialNumber, "12345678")
                    readExp.fulfill()
                    XCTAssertNil(blePeripheralProxy_1.characteristicReadTimers[MockBleDescriptor.serialNumberCharacteristicUUID])
                case .failure(let error):
                    XCTFail("characteristic read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadFailDueToDecodingError() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock decoding error
        bleSerialNumberProxy.decodingError = MockBleError.mockedError
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read not emitted on publisher
        bleSerialNumberProxy.didUpdateValuePublisher?
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSerialNumberProxy.read(
            cachePolicy: .never,
            timeout: .never
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCharacteristicProxyError else {
                        XCTFail("characteristic read was expected to fail with BleCharacteristicProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .decodingError = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BleCharacteristicProxyError category 'decodingError', got '\(proxyError.category)' instead")
                        return
                    }
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 2.0)
    }
    
    func testReadFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock read timeout
        try blePeripheral_1.delayOnRead = .seconds(10)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read not emitted on publisher
        bleSerialNumberProxy.didUpdateValuePublisher?
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSerialNumberProxy.read(
            cachePolicy: .never,
            timeout: .seconds(4)
        ) { result in
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
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 6.0)
    }
    
    func testReadFailDueToDiscoverServiceTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read not emitted on publisher
        bleSerialNumberProxy.didUpdateValuePublisher?
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSerialNumberProxy.read(
            cachePolicy: .never,
            timeout: .seconds(4)
        ) { result in
            switch result {
                case .success:
                    XCTFail("characteristic read was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralProxyError else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .serviceNotFound = proxyError.category else {
                        XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(proxyError.category)' instead")
                        return
                    }
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 6.0)
    }
    
    func testReadFailDueToDiscoverCharacteristicTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover characteristic timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic read
        let readExp = expectation(description: "waiting for characteristic read to fail")
        let publisherExp = expectation(description: "waiting for characteristic update NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test read not emitted on publisher
        bleSerialNumberProxy.didUpdateValuePublisher?
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        bleSerialNumberProxy.read(
            cachePolicy: .never,
            timeout: .seconds(4)
        ) { result in
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
                    readExp.fulfill()
            }
        }
        // Await expectations
        wait(for: [readExp, publisherExp], timeout: 6.0)
    }
    
}

// MARK: - Read tests (async)

extension BleCharacteristicReadProxyTests {
    
    func testReadAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test characteristic read
        do {
            let serialNumber = try await bleSerialNumberProxy.read(cachePolicy: .never, timeout: .never)
            XCTAssertEqual(serialNumber, "12345678")
        } catch {
            XCTFail("characteristic read failed with error: \(error)")
        }
    }
    
    func testReadFailDueToDecodingErrorAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock decoding error
        bleSerialNumberProxy.decodingError = MockBleError.mockedError
        // Test characteristic read
        do {
            _ = try await bleSerialNumberProxy.read(cachePolicy: .never, timeout: .never)
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch let proxyError as BleCharacteristicProxyError where proxyError.category == .decodingError {
            // NO OP
        } catch {
            XCTFail("characteristic read was expected to fail with BleCharacteristicProxyError category 'decodingError', got '\(error)' instead")
        }
    }
    
    func testReadFailDueToTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock read timeout
        try blePeripheral_1.delayOnRead = .seconds(10)
        // Test characteristic read
        do {
            _ = try await bleSerialNumberProxy.read(cachePolicy: .never, timeout: .seconds(4))
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .timeout {
            // NO OP
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'timeout', got '\(error)' instead")
        }
    }
    
    func testReadFailDueToDiscoverServiceTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover service timeout
        try blePeripheral_1.delayOnDiscoverServices = .seconds(10)
        // Test characteristic read
        do {
            _ = try await bleSerialNumberProxy.read(cachePolicy: .never, timeout: .seconds(4))
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .serviceNotFound {
            // NO OP
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'serviceNotFound', got '\(error)' instead")
        }
    }
    
    func testReadFailDueToDiscoverCharacteristicTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock discover characteristic timeout
        try blePeripheral_1.delayOnDiscoverCharacteristics = .seconds(10)
        // Test characteristic read
        do {
            _ = try await bleSerialNumberProxy.read(cachePolicy: .never, timeout: .seconds(4))
            XCTFail("characteristic read was expected to fail but succeeded instead")
        } catch let proxyError as BlePeripheralProxyError where proxyError.category == .characteristicNotFound {
            // NO OP
        } catch {
            XCTFail("characteristic read was expected to fail with BlePeripheralProxyError category 'characteristicNotFound', got '\(error)' instead")
        }
    }
    
}
