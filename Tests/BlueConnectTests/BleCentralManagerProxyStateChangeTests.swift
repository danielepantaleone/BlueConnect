//
//  BleCentralManagerProxyStateChangeTests.swift
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
    
final class BleCentralManagerProxyStateChangeTests: BlueConnectTests {
    
}

// MARK: - Test our mock

extension BleCentralManagerProxyStateChangeTests {
    
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
    
}

// MARK: - Test disconnection with central manager off

extension BleCentralManagerProxyStateChangeTests {
    
    func testPeripheralConnectFailAndDisconnectDueToBleCentralManagerGoingOff() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Assert initial peripheral state
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        XCTAssertEqual(try blePeripheral_2.state, .disconnected)
        // Connect peripheral 1
        connect(peripheral: try blePeripheral_1)
        XCTAssertEqual(try blePeripheral_1.state, .connected)
        // Mock connection delay
        bleCentralManager.delayOnConnection = .seconds(4)
        // Configure assertions
        let disconnectPublisherExp = expectation(description: "waiting for disconnection publisher to be called on blePeripheral_1")
        let connectFailPublisherExp = expectation(description: "waiting for connection failure publisher to be called on blePeripheral_2")
        let connectExp = expectation(description: "waiting for blePeripheral_2 connection to fail")
        // Test disconnection publisher to be called on blePeripheral_1
        let subscription1 = bleCentralManagerProxy.didDisconnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_1 }
            .sink { _, error in
                guard let error else {
                    XCTFail("expected BleCentralManagerProxyError, got nil instead")
                    return
                }
                switch error {
                    case BleCentralManagerProxyError.invalidState(let state):
                        XCTAssertEqual(state, .poweredOff)
                        disconnectPublisherExp.fulfill()
                    default:
                        XCTFail("peripheral disconnection was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                }
            }
        // Test connection failure publisher to be called on blePeripheral_2
        let subscription2 = bleCentralManagerProxy.didFailToConnectPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.peripheral.identifier == MockBleDescriptor.peripheralUUID_2 }
            .sink { _, error in
                switch error {
                    case BleCentralManagerProxyError.invalidState(let state):
                        XCTAssertEqual(state, .poweredOff)
                        connectFailPublisherExp.fulfill()
                    default:
                        XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                }
            }
        // Test connection failure on callback
        bleCentralManagerProxy.connect(
            peripheral: try blePeripheral_2,
            options: nil,
            timeout: .never
        ) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral connection was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState = proxyError else {
                        XCTFail("peripheral connection was expected to fail with BleCentralManagerProxyError.invalidState, got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(bleCentralManager.state, .poweredOff)
                    XCTAssertEqual(bleCentralManagerProxy.connectionRegistry.subscriptions(with: MockBleDescriptor.peripheralUUID_1), [])
                    connectExp.fulfill()
            }
        }
        // Wait a bit before turning off central manager.
        wait(.seconds(2))
        // Turn off ble central manager
        centralManager(state: .poweredOff)
        // Await expectations
        wait(for: [connectExp, connectFailPublisherExp, disconnectPublisherExp], timeout: 6.0)
        subscription1.cancel()
        subscription2.cancel()
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        XCTAssertEqual(try blePeripheral_2.state, .disconnected)
        XCTAssertEqual(bleCentralManagerProxy.connectionState[MockBleDescriptor.peripheralUUID_1], .disconnected)
        XCTAssertEqual(bleCentralManagerProxy.connectionState[MockBleDescriptor.peripheralUUID_2], .disconnected)
        XCTAssertEqual(bleCentralManagerProxy.connectionTimeouts.count, 0 )
        XCTAssertEqual(bleCentralManagerProxy.connectionCanceled.count, 0 )
    }
    
}

// MARK: - Test wait until ready

extension BleCentralManagerProxyStateChangeTests {
    
    func testWaitUntilReadySuccess() throws {
        XCTAssertNotEqual(bleCentralManager.state, .poweredOn)
        // Turn it on.
        bleCentralManager.state = .poweredOn
        // Await state change.
        let expectation = expectation(description: "waiting for central to be ready")
        bleCentralManagerProxy.waitUntilReady(timeout: .seconds(1)) { result in
            switch result {
                case .success:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("waiting for central manager to be ready failed with error: \(error)")
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadySuccessWithCentralAlreadyPoweredOn() throws {
        // Turn it on.
        centralManager(state: .poweredOn)
        // Await state change.
        let expectation = expectation(description: "waiting for central to notify already on state")
        bleCentralManagerProxy.waitUntilReady(timeout: .never) { result in
            switch result {
                case .success:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("waiting for central manager to be ready failed with error: \(error)")
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToUnauthorized() throws {
        // Make it unauthorized.
        centralManager(state: .unauthorized)
        // Await state not to change.
        let expectation = expectation(description: "waiting for central NOT to be ready")
        bleCentralManagerProxy.waitUntilReady(timeout: .never) { result in
            switch result {
                case .success:
                    XCTFail("central manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .unauthorized)
                    expectation.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToUnsupported() throws {
        // Make it unsupported.
        centralManager(state: .unsupported)
        // Await state not to change.
        let expectation = expectation(description: "waiting for central NOT to be ready")
        bleCentralManagerProxy.waitUntilReady(timeout: .never) { result in
            switch result {
                case .success:
                    XCTFail("central manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .unsupported)
                    expectation.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToTimeout() throws {
        XCTAssertNotEqual(bleCentralManager.state, .poweredOn)
        // Set state to simulate central manager taking time to be ready.
        centralManager(state: .resetting)
        // Await state change.
        let expectation = expectation(description: "waiting for central NOT to be ready")
        bleCentralManagerProxy.waitUntilReady(timeout: .seconds(1)) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("central manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .readyTimeout = proxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'readyTimeout', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(bleCentralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                    
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToCentralGoingUnauthorized() throws {
        XCTAssertNotEqual(bleCentralManager.state, .poweredOn)
        // Set state to simulate central manager taking time to be ready.
        centralManager(state: .resetting)
        // Await state change.
        let expectation = expectation(description: "waiting for central NOT to be ready")
        bleCentralManagerProxy.waitUntilReady(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("central manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .unauthorized)
                    XCTAssertEqual(bleCentralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                    
            }
        }
        // Go unauthorized.
        centralManager(state: .unauthorized)
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToCentralGoingUnsupported() throws {
        XCTAssertNotEqual(bleCentralManager.state, .poweredOn)
        // Set state to simulate central manager taking time to be ready.
        centralManager(state: .resetting)
        // Await state change.
        let expectation = expectation(description: "waiting for central NOT to be ready")
        bleCentralManagerProxy.waitUntilReady(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("central manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BleCentralManagerProxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .unsupported)
                    XCTAssertEqual(bleCentralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                    
            }
        }
        // Go unsupported.
        centralManager(state: .unsupported)
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
}

// MARK: - Test wait until ready (async)

extension BleCentralManagerProxyStateChangeTests {
    
    func testWaitUntilReadySuccessAsync() async throws {
        XCTAssertNotEqual(bleCentralManager.state, .poweredOn)
        // Turn it on.
        bleCentralManager.state = .poweredOn
        do {
            try await bleCentralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch {
            XCTFail("waiting for central manager to be ready failed with error: \(error)")
        }
    }
    
    func testWaitUntilReadySuccessWithCentralAlreadyPoweredOnAsync() async throws {
        // Turn it on.
        centralManager(state: .poweredOn)
        // Await state change (even if already changed).
        do {
            try await bleCentralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch {
            XCTFail("waiting for central manager to be ready failed with error: \(error)")
        }
    }
    
    func testWaitUntilReadyFailDueToUnauthorizedAsync() async throws {
        // Make it unauthorized.
        centralManager(state: .unauthorized)
        // Await state change failure.
        do {
            try await bleCentralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch BleCentralManagerProxyError.invalidState(let state) {
            XCTAssertEqual(state, .unauthorized)
        } catch {
            XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(error)' instead")
        }
    }
    
    func testWaitUntilReadyFailDueToUnsupportedAsync() async throws {
        // Make it unsupported.
        centralManager(state: .unsupported)
        // Await state change failure.
        do {
            try await bleCentralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch BleCentralManagerProxyError.invalidState(let state) {
            XCTAssertEqual(state, .unsupported)
        } catch {
            XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(error)' instead")
        }
    }
    
    func testWaitUntilReadyFailDueToTimeoutAsync() async throws {
        // Set state to simulate central manager taking time to be ready.
        centralManager(state: .resetting)
        // Await state change failure.
        do {
            try await bleCentralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch BleCentralManagerProxyError.readyTimeout {
            // OK
        } catch {
            XCTFail("central manager ready await was expected to fail with BleCentralManagerProxyError 'readyTimeout', got '\(error)' instead")
        }
    }
    
    func testWaitUntilReadyFailDueToTaskCancellation() async throws {
        XCTAssertNotEqual(bleCentralManager.state, .poweredOn)
        let proxy: BleCentralManagerProxy! = bleCentralManagerProxy
        let started = XCTestExpectation(description: "Task started")
        let task = Task {
            started.fulfill() // Signal that the task has started
            do {
                try await proxy.waitUntilReady(timeout: .seconds(2))
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
