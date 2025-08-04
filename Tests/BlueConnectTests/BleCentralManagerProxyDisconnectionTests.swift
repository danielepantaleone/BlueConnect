//
//  BleCentralManagerProxyDisconnectionTests.swift
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

final class BleCentralManagerProxyDisconnectionTests: BlueConnectTests {
    
}

// MARK: - Test disconnection

extension BleCentralManagerProxyDisconnectionTests {
    
    func testPeripheralDisconnect() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test disconnection
        let disconnectExp = expectation(description: "waiting for peripheral to disconnect")
        let publisherExp = expectation(description: "waiting for peripheral disconnection to be signaled by publisher")
        // Test disconnection emit on publisher
        let subscription = bleCentralManagerProxy.didDisconnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _, error in
                guard error == nil else {
                    XCTFail("peripheral disconnection was not expected to generate an error")
                    return
                }
                publisherExp.fulfill()
            }
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
        subscription.cancel()
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    func testPeripheralDisconnectWithPeripheralConnecting() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Delay connection to mock connecting state
        bleCentralManager.delayOnConnection = .seconds(4)
        // Test disconnection and connection failure
        let connectFailExp = expectation(description: "waiting for peripheral to fail connection")
        let disconnectExp = expectation(description: "waiting for peripheral to disconnect")
        let publisherExp = expectation(description: "waiting for peripheral connection failure to be signaled by publisher")
        // Connect the peripheral
        bleCentralManagerProxy.connect(peripheral: try blePeripheral_1, options: nil, timeout: .never) { result in
            switch result {
                case .success:
                    XCTFail("peripheral connection succeeded but was expected to fail")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError, got '\(String(describing: error))' instead")
                        return
                    }
                    guard case .connectionCanceled = proxyError else {
                        XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    connectFailExp.fulfill()
            }
        }
        // Test disconnection emit on publisher
        let subscription = bleCentralManagerProxy.didFailToConnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _, error in
                guard let proxyError = error as? BleCentralManagerProxyError else {
                    XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError, got '\(String(describing: error))' instead")
                    return
                }
                guard case .connectionCanceled = proxyError else {
                    XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                    return
                }
                publisherExp.fulfill()
            }
        // Test connection on callback
        bleCentralManagerProxy.disconnect(peripheral: try blePeripheral_1) { result in
                switch result {
                    case .success:
                        disconnectExp.fulfill()
                    case .failure(let error):
                        XCTFail("peripheral disconnection failed with error: \(error)")
                }
            }
        wait(for: [disconnectExp, publisherExp, connectFailExp], timeout: 2.0)
        subscription.cancel()
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    func testPeripheralDisconnectWithPeripheralAlreadyDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test disconnection or disconnected peripheral
        let disconnectExp = expectation(description: "waiting for peripheral to disconnect even if already disconnected")
        let publisherExp = expectation(description: "waiting for peripheral disconnection NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test disconnection not to be emitted on publisher because already connected
        let subscription = bleCentralManagerProxy.didDisconnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _, error in
                guard error == nil else {
                    XCTFail("peripheral disconnection was not expected to generate an error")
                    return
                }
                publisherExp.fulfill()
            }
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
        subscription.cancel()
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    func testPeripheralDisconnectWithPeripheralAlreadyDisconnecting() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Delay disconnection to mock disconnecting state
        bleCentralManager.delayOnDisconnection = .seconds(2)
        // Test disconnection or disconnected peripheral
        let disconnectExp = expectation(description: "waiting for peripheral to disconnect")
        disconnectExp.expectedFulfillmentCount = 3
        let publisherExp = expectation(description: "waiting for peripheral disconnection to be signaled by publisher")
        // Test disconnection not to be emitted on publisher because already connected
        let subscription = bleCentralManagerProxy.didDisconnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _, error in
                guard error == nil else {
                    XCTFail("peripheral disconnection was not expected to generate an error")
                    return
                }
                publisherExp.fulfill()
            }
        // Test connection on callback
        for _ in 0..<3 {
            bleCentralManagerProxy.disconnect(peripheral: try blePeripheral_1) { result in
                switch result {
                    case .success:
                        disconnectExp.fulfill()
                    case .failure(let error):
                        XCTFail("peripheral disconnection failed with error: \(error)")
                }
            }
        }
        wait(for: [disconnectExp, publisherExp], timeout: 6.0)
        subscription.cancel()
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    func testPeripheralDisconnectDueToBleManagerGoingOff() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Test disconnection
        let expectation = expectation(description: "waiting for peripheral disconnection to be signaled by publisher")
        // Test disconnection emit on publisher
        let subscription = bleCentralManagerProxy.didDisconnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { peripheral, error in
                guard let proxyError = error as? BleCentralManagerProxyError else {
                    XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError, got '\(String(describing: error))' instead")
                    return
                }
                guard case .invalidState(let state) = proxyError else {
                    XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                    return
                }
                XCTAssertEqual(state, .poweredOff)
                expectation.fulfill()
            }
        // Turn off ble central manager
        centralManager(state: .poweredOff)
        // Check final state
        wait(for: [expectation], timeout: 2.0)
        subscription.cancel()
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
    func testPeripheralDisconnectFailDueToBleCentralManagerOff() throws {
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        let disconnectExp = expectation(description: "waiting for peripheral disconnection to fail")
        let disconnectPublisherExp = expectation(description: "waiting for publisher not to be called")
        disconnectPublisherExp.isInverted = true
        // Test publisher not called
        let subscription = bleCentralManagerProxy.didDisconnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _ in disconnectPublisherExp.fulfill() }
        // Test connection failure on callback
        bleCentralManagerProxy.disconnect(peripheral: try blePeripheral_1) { result in
            switch result {
                case .success:
                    XCTFail("peripheral disconnection was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .poweredOff)
                    disconnectExp.fulfill()
            }
        }
        wait(for: [disconnectExp, disconnectPublisherExp], timeout: 2.0)
        subscription.cancel()
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
    }
    
}

// MARK: - Test disconnection (async)

extension BleCentralManagerProxyDisconnectionTests {
    
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
    
    func testPeripheralDisconnectFailDueToBleCentralManagerOffAsync() async throws {
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        do {
            try await bleCentralManagerProxy.disconnect(peripheral: try blePeripheral_1)
        } catch BleCentralManagerProxyError.invalidState(let state) {
            XCTAssertEqual(state, .poweredOff)
        } catch {
            XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(error)' instead")
        }
    }
    
    func testPeripheralDisconnectFailDueToTaskCancellation() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Mock disconnection delay
        bleCentralManager.delayOnDisconnection = .seconds(2)
        // Begin test
        let proxy: BleCentralManagerProxy! = bleCentralManagerProxy
        let peripheral: BlePeripheral = try blePeripheral_1
        let started = XCTestExpectation(description: "Task started")
        let task = Task {
            started.fulfill() // Signal that the task has started
            do {
                try await proxy.disconnect(peripheral: peripheral)
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
    
    func testPeripheralDisconnectFailOnSingleTaskDueToTaskCancellation() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_1)
        // Begin test
        let central: MockBleCentralManager! = bleCentralManager
        let proxy: BleCentralManagerProxy! = bleCentralManagerProxy
        let peripheral: BlePeripheral = try blePeripheral_1
        let started = XCTestExpectation(description: "Task started")
        started.expectedFulfillmentCount = 2
        let task1 = Task {
            started.fulfill() // Signal that the task has started
            do {
                central.delayOnDisconnection = .seconds(2)
                try await proxy.disconnect(peripheral: peripheral)
                XCTFail("Expected task to be cancelled, but it succeeded")
            } catch is CancellationError {
                // Expected path
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
        let task2 = Task {
            started.fulfill() // Signal that the task has started
            do {
                central.delayOnDisconnection = .seconds(2)
                try await proxy.disconnect(peripheral: peripheral)
            } catch is CancellationError {
                XCTFail("Test failed due to cancellation of second task")
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
        // Wait for the task to begin.
        await fulfillment(of: [started], timeout: 1.0)
        // Now cancel the task.
        task1.cancel()
        // Await the task to ensure cleanup.
        _ = await task1.result
        _ = await task2.result
    }
    
}
