//
//  BleCentralManagerProxyTests.swift
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

final class BleCentralManagerProxyTests: XCTestCase {
    
    // MARK: - Properties
    
    var bleCentralManager: MockBleCentralManager!
    var bleCentralManagerProxy: BleCentralManagerProxy!
    
    var blePeripheral_1: MockBlePeripheral {
        get throws {
            let peripheralId = try XCTUnwrap(MockBleDescriptor.peripheralUUID_1)
            let peripheral = bleCentralManager.retrievePeripherals(withIds: [peripheralId]).first
            return try XCTUnwrap(peripheral as? MockBlePeripheral)
        }
    }
    
    var subscriptions: Set<AnyCancellable> = []
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        bleCentralManager = .init()
        bleCentralManager.discoveredPeripherals([
            MockBlePeripheral(
                identifier: MockBleDescriptor.peripheralUUID_1,
                name: nil,
                serialNumber: "12345678",
                batteryLevel: 77,
                firmwareRevision: "1.0.7",
                hardwareRevision: "2.0.4",
                secret: "abcd"),
            MockBlePeripheral(
                identifier: MockBleDescriptor.peripheralUUID_1,
                name: "PERIPHERAL_2",
                serialNumber: "87654321",
                batteryLevel: 43,
                firmwareRevision: "1.0.2",
                hardwareRevision: "2.0.1",
                secret: "efgh")
        ])
        bleCentralManagerProxy = .init(centralManager: bleCentralManager)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        bleCentralManagerProxy = nil
        bleCentralManager = nil
    }
    
    // MARK: - Test state change
    
    func testCentralManagerPowerOn() throws {
        centralManager(state: .poweredOn)
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
    }
    
    func testCentralManagerPowerOnAndThenOff() throws {
        centralManager(state: .poweredOn)
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        centralManager(state: .poweredOff)
        XCTAssertEqual(bleCentralManager.state, .poweredOff)
    }

    // MARK: - Test connection
    
    func testPeripheralConnect() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Assert initial peripheral state
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        let connectExp = expectation(description: "waiting for peripheral to connect")
        let publisherExp = expectation(description: "waiting for peripheral connection to be signaled by publisher")
        // Test connection emit on publisher
        bleCentralManagerProxy.didConnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test connection on callback
        bleCentralManagerProxy.connect(
            peripheral: try blePeripheral_1,
            options: nil,
            timeout: .never) { result in
                switch result {
                    case .success:
                        connectExp.fulfill()
                    case .failure(let error):
                        XCTFail("peripheral connection failed with error: \(error)")
                }
            }
        wait(for: [connectExp, publisherExp], timeout: 2.0)
        XCTAssertEqual(try blePeripheral_1.state, .connected)
    }
    
    func testPeripheralConnectAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Assert initial peripheral state
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        do {
            try await bleCentralManagerProxy.connect(
                peripheral: try blePeripheral_1,
                options: nil,
                timeout: .never)
        } catch {
            XCTFail("peripheral connection failed with error: \(error)")
        }
        XCTAssertEqual(try blePeripheral_1.state, .connected)
    }
    
    func testPeripheralConnectWithPeripheralAlreadyConnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test second connection
        let connectExp = expectation(description: "waiting for peripheral to connect even if already connected")
        let publisherExp = expectation(description: "waiting for peripheral connection NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test connection not to be emitted on publisher because already connected
        bleCentralManagerProxy.didConnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test connection on callback
        bleCentralManagerProxy.connect(
            peripheral: try blePeripheral_1,
            options: nil,
            timeout: .never) { result in
                switch result {
                    case .success:
                        connectExp.fulfill()
                    case .failure(let error):
                        XCTFail("peripheral connection failed with error: \(error)")
                }
            }
        wait(for: [connectExp, publisherExp], timeout: 2.0)
        XCTAssertEqual(try blePeripheral_1.state, .connected)
    }
    
    func testPeripheralConnectFailDueToBleCentralManagerOff() throws {
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        let connectExp = expectation(description: "waiting for peripheral connection to fail")
        let publisherExp = expectation(description: "waiting for publisher not to be called")
        publisherExp.isInverted = true
        // Test publisher not called
        bleCentralManagerProxy.didConnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test connection failure on callback
        bleCentralManagerProxy.connect(
            peripheral: try blePeripheral_1,
            options: nil,
            timeout: .never) { result in
                switch result {
                    case .success:
                        XCTFail("peripheral connection was expected to fail but succeeded instead")
                    case .failure(let error):
                        guard let proxyError = error as? BleCentralManagerProxyError else {
                            XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError, got '\(type(of: error))' instead")
                            return
                        }
                        guard case .invalidState(let state) = proxyError.category else {
                            XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError category 'invalidState', got '\(proxyError.category)' instead")
                            return
                        }
                        XCTAssertEqual(state, .poweredOff)
                        connectExp.fulfill()
                }
            }
        wait(for: [connectExp, publisherExp], timeout: 2.0)
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    func testPeripheralConnectFailDueToBleCentralManagerOffAsync() async throws {
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        do {
            try await bleCentralManagerProxy.connect(
                peripheral: try blePeripheral_1,
                options: nil,
                timeout: .never)
        } catch let proxyError as BleCentralManagerProxyError {
            guard case .invalidState(let state) = proxyError.category else {
                XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError category 'invalidState', got '\(proxyError.category)' instead")
                return
            }
            XCTAssertEqual(state, .poweredOff)
        } catch {
            XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError, got '\(type(of: error))' instead")
        }
    }
    
    func testPeripheralConnectFailDueToTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Assert initial peripheral state
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        let connectExp = expectation(description: "waiting for peripheral connection to fail")
        let publisherExp = expectation(description: "waiting for publisher not to be called")
        publisherExp.isInverted = true
        // Mock connection timeout
        bleCentralManager.timeoutOnConnection = true
        // Test publisher not called
        bleCentralManagerProxy.didConnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test connection failure on callback
        bleCentralManagerProxy.connect(
            peripheral: try blePeripheral_1,
            options: nil,
            timeout: .seconds(2)) { result in
                switch result {
                    case .success:
                        XCTFail("peripheral connection was expected to fail but succeeded instead")
                    case .failure(let error):
                        guard let proxyError = error as? BleCentralManagerProxyError else {
                            XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError, got '\(type(of: error))' instead")
                            return
                        }
                        guard case .timeout = proxyError.category else {
                            XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError category 'timeout', got '\(proxyError.category)' instead")
                            return
                        }
                        connectExp.fulfill()
                }
            }
        wait(for: [connectExp, publisherExp], timeout: 4.0)
        // Assert final peripheral state
        XCTAssertEqual(try blePeripheral_1.state, .connecting)
    }
    
    // MARK: - Test disconnection
    
    func testPeripheralDisconnect() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test disconnection
        let disconnectExp = expectation(description: "waiting for peripheral to disconnect")
        let publisherExp = expectation(description: "waiting for peripheral disconnection to be signaled by publisher")
        // Test disconnection emit on publisher
        bleCentralManagerProxy.didDisconnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
        // Test connection on callback
        bleCentralManagerProxy.disconnect(peripheral: try blePeripheral_1) { result in
                switch result {
                    case .success:
                        disconnectExp.fulfill()
                    case .failure(let error):
                        XCTFail("peripheral disconnection failed with error: \(error)")
                }
            }
        wait(for: [disconnectExp, publisherExp], timeout: 2.0)
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    func testPeripheralDisconnectAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test disconnection
        do {
            try await bleCentralManagerProxy.disconnect(peripheral: try blePeripheral_1)
        } catch {
            XCTFail("peripheral disconnection failed with error: \(error)")
        }
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    // MARK: - Functions
    
    func centralManager(state: CBManagerState) {
        XCTAssertNotEqual(bleCentralManager.state, state)
        let expectation = expectation(description: "waiting for bluetooth state to change to '\(state)'")
        bleCentralManagerProxy.didUpdateStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == state }
            .sink { _ in expectation.fulfill() }
            .store(in: &subscriptions)
        bleCentralManager.state = state
        wait(for: [expectation], timeout: 2.0)
    }
    
    func connect(peripheral: BlePeripheral) {
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        XCTAssertEqual(peripheral.state, .disconnected)
        let expectation = expectation(description: "waiting for peripheral to connect")
        bleCentralManagerProxy.connect(
            peripheral: peripheral,
            options: nil,
            timeout: .never) { result in
                switch result {
                    case .success:
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("peripheral connection failed with error: \(error)")
                }
            }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(peripheral.state, .connected)
    }
    
}
