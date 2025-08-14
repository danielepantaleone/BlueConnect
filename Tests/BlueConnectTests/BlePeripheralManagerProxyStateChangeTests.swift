//
//  BlePeripheralManagerProxyStateChangeTests.swift
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
    
final class BlePeripheralManagerProxyStateChangeTests: BlueConnectTests {
    
}

// MARK: - Test our mock

extension BlePeripheralManagerProxyStateChangeTests {
    
    func testPeripheralManagerPowerOn() throws {
        peripheralManager(state: .poweredOn)
        XCTAssertEqual(blePeripheralManager.state, .poweredOn)
    }
    
    func testPeripheralManagerPowerOnAndThenOff() throws {
        peripheralManager(state: .poweredOn)
        XCTAssertEqual(blePeripheralManager.state, .poweredOn)
        peripheralManager(state: .poweredOff)
        XCTAssertEqual(blePeripheralManager.state, .poweredOff)
    }
    
}

// MARK: - Test wait until ready

extension BlePeripheralManagerProxyStateChangeTests {
    
    func testWaitUntilReadySuccess() throws {
        XCTAssertNotEqual(blePeripheralManager.state, .poweredOn)
        // Turn it on.
        blePeripheralManager.state = .poweredOn
        // Await state change.
        let expectation = expectation(description: "waiting for peripheral manager to be ready")
        blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(1)) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("waiting for peripheral manager to be ready failed with error: \(error)")
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadySuccessWithPeripheralManagerAlreadyPoweredOn() throws {
        // Turn it on.
        peripheralManager(state: .poweredOn)
        // Await state change.
        let expectation = expectation(description: "waiting for peripheral to notify already on state")
        blePeripheralManagerProxy.waitUntilReady(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("waiting for peripheral manager to be ready failed with error: \(error)")
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToUnauthorized() throws {
        // Make it unauthorized.
        peripheralManager(state: .unauthorized)
        // Await state not to change.
        let expectation = expectation(description: "waiting for peripheral manager NOT to be ready")
        blePeripheralManagerProxy.waitUntilReady(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .unauthorized)
                    XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToUnsupported() throws {
        // Make it unsupported.
        peripheralManager(state: .unsupported)
        // Await state not to change.
        let expectation = expectation(description: "waiting for peripheral manager NOT to be ready")
        blePeripheralManagerProxy.waitUntilReady(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    XCTAssertEqual(state, .unsupported)
                    expectation.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToTimeout() throws {
        XCTAssertNotEqual(blePeripheralManager.state, .poweredOn)
        // Set state to simulate peripheral manager taking time to be ready.
        peripheralManager(state: .resetting)
        // Await state change.
        let expectation = expectation(description: "waiting for peripheral manager NOT to be ready")
        blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(1)) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .readyTimeout = proxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'readyTimeout', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                    
            }
        }
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToPeripheralManagerGoingUnauthorized() throws {
        XCTAssertNotEqual(blePeripheralManager.state, .poweredOn)
        // Set state to simulate peripheral manager taking time to be ready.
        peripheralManager(state: .resetting)
        // Await state change.
        let expectation = expectation(description: "waiting for peripheral manager NOT to be ready")
        blePeripheralManagerProxy.waitUntilReady(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .unauthorized)
                    XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                    
            }
        }
        // Go unauthorized.
        peripheralManager(state: .unauthorized)
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWaitUntilReadyFailDueToPeripheralManagerGoingUnsupported() throws {
        XCTAssertNotEqual(blePeripheralManager.state, .poweredOn)
        // Set state to simulate peripheral manager taking time to be ready.
        peripheralManager(state: .resetting)
        // Await state change.
        let expectation = expectation(description: "waiting for peripheral manager NOT to be ready")
        blePeripheralManagerProxy.waitUntilReady(timeout: .never) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success:
                    XCTFail("peripheral manager ready await was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .unsupported)
                    XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
                    expectation.fulfill()
                    
            }
        }
        // Go unsupported.
        peripheralManager(state: .unsupported)
        // Await expectation fullfilment.
        wait(for: [expectation], timeout: 2.0)
    }
    
}

// MARK: - Test wait until ready (async)

extension BlePeripheralManagerProxyStateChangeTests {
    
    func testWaitUntilReadySuccessAsync() async throws {
        XCTAssertNotEqual(blePeripheralManager.state, .poweredOn)
        // Turn it on.
        blePeripheralManager.state = .poweredOn
        do {
            try await blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch {
            XCTFail("waiting for peripheral manager to be ready failed with error: \(error)")
        }
        // Assert final state
        XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
    }
    
    func testWaitUntilReadySuccessWithPeripheralManagerAlreadyPoweredOnAsync() async throws {
        // Turn it on.
        peripheralManager(state: .poweredOn)
        // Await state change (even if already changed).
        do {
            try await blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch {
            XCTFail("waiting for peripheral manager to be ready failed with error: \(error)")
        }
        // Assert final state
        XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
    }
    
    func testWaitUntilReadyFailDueToUnauthorizedAsync() async throws {
        // Make it unauthorized.
        peripheralManager(state: .unauthorized)
        // Await state change failure.
        do {
            try await blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch BlePeripheralManagerProxyError.invalidState(let state) {
            XCTAssertEqual(state, .unauthorized)
            XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(error)' instead")
        }
    }
    
    func testWaitUntilReadyFailDueToUnsupportedAsync() async throws {
        // Make it unsupported.
        peripheralManager(state: .unsupported)
        // Await state change failure.
        do {
            try await blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch BlePeripheralManagerProxyError.invalidState(let state) {
            XCTAssertEqual(state, .unsupported)
            XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(error)' instead")
        }
    }
    
    func testWaitUntilReadyFailDueToTimeoutAsync() async throws {
        // Set state to simulate peripheral manager taking time to be ready.
        peripheralManager(state: .resetting)
        // Await state change failure.
        do {
            try await blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(1))
        } catch BlePeripheralManagerProxyError.readyTimeout {
            XCTAssertEqual(blePeripheralManagerProxy.waitUntilReadyRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral manager ready await was expected to fail with BlePeripheralManagerProxyError 'readyTimeout', got '\(error)' instead")
        }
    }
    
    func testWaitUntilReadyFailDueToTaskCancellationAsync() async throws {
        XCTAssertNotEqual(blePeripheralManager.state, .poweredOn)
        let proxy: BlePeripheralManagerProxy! = blePeripheralManagerProxy
        let started = XCTestExpectation(description: "Task started")
        let task = Task {
            started.fulfill() // Signal that the task has started
            do {
                try await proxy.waitUntilReady(timeout: .seconds(2))
                XCTFail("Expected task to be cancelled, but it succeeded")
            } catch is CancellationError {
                XCTAssertEqual(proxy.waitUntilReadyRegistry.subscriptions(), [])
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
    
    func testWaitUntilReadyFailOnSingleTaskDueToTaskCancellationAsync() async throws {
        XCTAssertNotEqual(blePeripheralManager.state, .poweredOn)
        let proxy: BlePeripheralManagerProxy! = blePeripheralManagerProxy
        let started = XCTestExpectation(description: "Task started")
        started.expectedFulfillmentCount = 2
        let task1 = Task {
            started.fulfill() // Signal that the first task has started
            do {
                try await proxy.waitUntilReady(timeout: .seconds(2))
                XCTFail("Expected task to be cancelled, but it succeeded")
            } catch is CancellationError {
                // Expected path
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
        let task2 = Task {
            started.fulfill() // Signal that the second task has started
            do {
                try await proxy.waitUntilReady(timeout: .seconds(2))
                XCTFail("Expected task to raise readyTimeout, but it succeeded")
            } catch is CancellationError {
                XCTFail("Test failed due to cancellation of second task")
            } catch BlePeripheralManagerProxyError.readyTimeout {
                XCTAssertEqual(proxy.waitUntilReadyRegistry.subscriptions(), [])
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
