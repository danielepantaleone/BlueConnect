//
//  BlePeripheralManagerProxyAdvertisingTests.swift
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
    
final class BlePeripheralManagerProxyAdvertisingTests: BlueConnectTests {
    
}

// MARK: - Test start advertising

extension BlePeripheralManagerProxyAdvertisingTests {
    
    func testStartAdvertising() throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to start")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising to be emitted on publisher")
        // Assert over publisher notify.
        let subscription = blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherExp.fulfill() }
        // Assert over callback notify.
        blePeripheralManagerProxy.startAdvertising { result in
            switch result {
                case .success:
                    callbackExp.fulfill()
                case .failure(let error):
                    XCTFail("waiting for peripheral manager advertising to start failed with error: \(error)")
            }
        }
        // Await expectation fullfilment.
        wait(for: [callbackExp, publisherExp], timeout: 2.0)
        subscription.cancel()
        // Assert final state.
        XCTAssertTrue(blePeripheralManagerProxy.isAdvertising)
        XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
    }
    
    func testStartAdvertisingFailDueToPeripheralManagerOff() throws {
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to fail")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising NOT to be emitted on publisher")
        publisherExp.isInverted = true
        // Assert over publisher notify.
        let subscription = blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherExp.fulfill() }
        // Assert over callback notify.
        blePeripheralManagerProxy.startAdvertising { result in
            switch result {
                case .success:
                    XCTFail("peripheral manager advertising was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager advertising was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("peripheral manager advertising was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .poweredOff)
                    callbackExp.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [callbackExp, publisherExp], timeout: 2.0)
        subscription.cancel()
        // Assert final state
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
    }
    
    func testStartAdvertisingFailDueToTimeout() throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to fail")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising NOT to be emitted on publisher")
        publisherExp.isInverted = true
        // Mock advertising timeout.
        blePeripheralManager.delayOnStartAdvertising = .seconds(10)
        // Assert over publisher notify.
        let subscription = blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherExp.fulfill() }
        // Assert over callback notify.
        blePeripheralManagerProxy.startAdvertising(timeout: .seconds(2)) { result in
            switch result {
                case .success:
                    XCTFail("peripheral manager advertising was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager advertising was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .advertisingTimeout = proxyError else {
                        XCTFail("peripheral manager advertising was expected to fail with BlePeripheralManagerProxyError 'advertisingTimeout', got '\(proxyError)' instead")
                        return
                    }
                    callbackExp.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [callbackExp, publisherExp], timeout: 4.0)
        subscription.cancel()
        // Assert final state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
    }
    
    func testStartAdvertisingFailDueToError() throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to fail")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising NOT to be emitted on publisher")
        publisherExp.isInverted = true
        // Mock advertising timeout.
        blePeripheralManager.errorOnStartAdvertising = MockBleError.mockedError
        // Assert over publisher notify.
        let subscription = blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherExp.fulfill() }
        // Assert over callback notify.
        blePeripheralManagerProxy.startAdvertising { result in
            switch result {
                case .success:
                    XCTFail("peripheral manager advertising was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let mockedError = error as? MockBleError else {
                        XCTFail("peripheral manager advertising was expected to fail with MockBleError, got '\(error)' instead")
                        return
                    }
                    XCTAssertEqual(mockedError, .mockedError)
                    callbackExp.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [callbackExp, publisherExp], timeout: 2.0)
        subscription.cancel()
        // Assert final state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
    }
    
}

// MARK: - Test start advertising (async)

extension BlePeripheralManagerProxyAdvertisingTests {
    
    func testStartAdvertisingAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Test
        do {
            try await blePeripheralManagerProxy.startAdvertising()
            XCTAssertTrue(blePeripheralManagerProxy.isAdvertising)
            XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral manager advertising start failed with error: \(error)")
        }
    }
    
    func testStartAdvertisingFailDueToPeripheralManagerOffAsync() async throws {
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        do {
            try await blePeripheralManagerProxy.startAdvertising()
        } catch BlePeripheralManagerProxyError.invalidState(let state) {
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
            XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
            XCTAssertEqual(state, .poweredOff)
        } catch {
            XCTFail("peripheral manager advertising start was expected to fail with BlePeripheralManagerProxyError.invalidState, got '\(error)' instead")
        }
    }
    
    func testStartAdvertisingFailDueToTimeoutAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Mock advertising timeout
        blePeripheralManager.delayOnStartAdvertising = .seconds(10)
        // Test timeout
        do {
            try await blePeripheralManagerProxy.startAdvertising(timeout: .seconds(2))
        } catch BlePeripheralManagerProxyError.advertisingTimeout {
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
            XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral manager advertising start was expected to fail with BlePeripheralManagerProxyError.advertisingTimeout, got '\(error)' instead")
        }
    }
    
    func testStartAdvertisingFailDueToErrorAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Mock advertising timeout
        blePeripheralManager.errorOnStartAdvertising = MockBleError.mockedError
        // Test timeout
        do {
            try await blePeripheralManagerProxy.startAdvertising(timeout: .seconds(2))
        } catch MockBleError.mockedError {
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
            XCTAssertEqual(blePeripheralManagerProxy.startAdvertisingRegistry.subscriptions(), [])
        } catch {
            XCTFail("peripheral manager advertising start was expected to fail with MockBleError.mockedError, got '\(error)' instead")
        }
    }
    
    func testStartAdvertisingFailDueToTaskCancellationAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Mock delay
        blePeripheralManager.delayOnStartAdvertising = .seconds(2)
        // Test
        let proxy: BlePeripheralManagerProxy! = blePeripheralManagerProxy
        let started = XCTestExpectation(description: "Task started")
        let task = Task {
            started.fulfill() // Signal that the task has started
            do {
                try await proxy.startAdvertising()
                XCTFail("Expected task to be cancelled, but it succeeded")
            } catch is CancellationError {
                XCTAssertEqual(proxy.startAdvertisingRegistry.subscriptions(), [])
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
    
    func testStartAdvertisingFailOnSingleTaskDueToTaskCancellationAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Mock delay
        blePeripheralManager.delayOnStartAdvertising = .seconds(2)
        // Begin test
        let proxy: BlePeripheralManagerProxy! = blePeripheralManagerProxy
        let started = XCTestExpectation(description: "Task started")
        started.expectedFulfillmentCount = 2
        let task1 = Task {
            started.fulfill() // Signal that the first task has started
            do {
                try await proxy.startAdvertising()
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
                try await proxy.startAdvertising()
                XCTAssertTrue(proxy.isAdvertising)
                XCTAssertEqual(proxy.startAdvertisingRegistry.subscriptions(), [])
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

// MARK: - Test stop advertising

extension BlePeripheralManagerProxyAdvertisingTests {
    
    func testStopAdvertising() throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Start advertising.
        try startAdvertising()
        // Check for monitor to be running.
        XCTAssertNotNil(blePeripheralManagerProxy.advertisingMonitor)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to stop")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising to be emitted on publisher")
        // Assert over publisher notify.
        let subscription = blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == false }
            .sink { _ in publisherExp.fulfill() }
        // Assert over callback notify.
        blePeripheralManagerProxy.stopAdvertising { result in
            switch result {
                case .success:
                    callbackExp.fulfill()
                case .failure(let error):
                    XCTFail("waiting for peripheral manager advertising to stop failed with error: \(error)")
            }
        }
        // Await expectation fullfilment.
        wait(for: [callbackExp, publisherExp], timeout: 4.0)
        subscription.cancel()
        // Assert final state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertEqual(blePeripheralManagerProxy.stopAdvertisingRegistry.subscriptions(), [])
        XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
    }
    
    func testStopAdvertisingWhenNoAdvertisingAtAll() throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Check for monitor NOT to be running.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to stop because not running")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising NOT to be emitted on publisher")
        publisherExp.isInverted = true
        // Assert over publisher notify.
        let subscription = blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == false }
            .sink { _ in publisherExp.fulfill() }
        // Assert over callback notify.
        blePeripheralManagerProxy.stopAdvertising { result in
            switch result {
                case .success:
                    callbackExp.fulfill()
                case .failure(let error):
                    XCTFail("waiting for peripheral manager advertising to stop failed with error: \(error)")
            }
        }
        // Await expectation fullfilment.
        wait(for: [callbackExp, publisherExp], timeout: 4.0)
        subscription.cancel()
        // Assert final state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertEqual(blePeripheralManagerProxy.stopAdvertisingRegistry.subscriptions(), [])
        XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
    }
    
    func testStopAdvertisingFailDueToPeripheralManagerOff() throws {
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising stop to fail")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising stop NOT to be emitted on publisher")
        publisherExp.isInverted = true
        // Assert over publisher notify.
        let subscription = blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == false }
            .sink { _ in publisherExp.fulfill() }
        // Assert over callback notify.
        blePeripheralManagerProxy.stopAdvertising { result in
            switch result {
                case .success:
                    XCTFail("peripheral manager advertising was expected to fail but succeeded instead")
                case .failure(let error):
                    guard let proxyError = error as? BlePeripheralManagerProxyError else {
                        XCTFail("peripheral manager advertising was expected to fail with BlePeripheralManagerProxyError, got '\(error)' instead")
                        return
                    }
                    guard case .invalidState(let state) = proxyError else {
                        XCTFail("peripheral manager advertising was expected to fail with BlePeripheralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                        return
                    }
                    XCTAssertEqual(state, .poweredOff)
                    callbackExp.fulfill()
            }
        }
        // Await expectation fullfilment.
        wait(for: [callbackExp, publisherExp], timeout: 2.0)
        subscription.cancel()
        // Assert final state
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertEqual(blePeripheralManagerProxy.stopAdvertisingRegistry.subscriptions(), [])
        XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
    }
    
}

// MARK: - Test stop advertising (async)

extension BlePeripheralManagerProxyAdvertisingTests {
    
    func testStopAdvertisingAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Start advertising.
        try startAdvertising()
        // Check for monitor to be running.
        XCTAssertNotNil(blePeripheralManagerProxy.advertisingMonitor)
        // Test
        do {
            try await blePeripheralManagerProxy.stopAdvertising()
            wait(.seconds(1)) // for advertisingMonitor to be nil (go figure....)
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
            XCTAssertEqual(blePeripheralManagerProxy.stopAdvertisingRegistry.subscriptions(), [])
            XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
        } catch {
            XCTFail("peripheral manager advertising to stop failed with error: \(error)")
        }
    }
    
    func testStopAdvertisingWhenNoAdvertisingAtAllAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Check for monitor NOT to be running.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
        // Test
        do {
            try await blePeripheralManagerProxy.stopAdvertising()
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
            XCTAssertEqual(blePeripheralManagerProxy.stopAdvertisingRegistry.subscriptions(), [])
            XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
        } catch {
            XCTFail("peripheral manager advertising to stop failed with error: \(error)")
        }
    }
    
    func testStopAdvertisingFailDueToPeripheralManagerOffAsync() async throws {
        do {
            try await blePeripheralManagerProxy.stopAdvertising()
        } catch BlePeripheralManagerProxyError.invalidState(let state) {
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
            XCTAssertEqual(blePeripheralManagerProxy.stopAdvertisingRegistry.subscriptions(), [])
            XCTAssertNil(blePeripheralManagerProxy.advertisingMonitor)
            XCTAssertEqual(state, .poweredOff)
        } catch {
            XCTFail("peripheral manager advertising stop was expected to fail with BlePeripheralManagerProxyError.invalidState, got '\(error)' instead")
        }
    }
    
    func testStopAdvertisingFailDueToTaskCancellationAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Start advertising.
        try startAdvertising()
        // Check for monitor to be running.
        XCTAssertNotNil(blePeripheralManagerProxy.advertisingMonitor)
        // Mock delay
        blePeripheralManager.delayOnStopAdvertising = .seconds(2)
        // Test
        let proxy: BlePeripheralManagerProxy! = blePeripheralManagerProxy
        let started = XCTestExpectation(description: "Task started")
        let task = Task {
            started.fulfill() // Signal that the task has started
            do {
                try await proxy.stopAdvertising()
                XCTFail("Expected task to be cancelled, but it succeeded")
            } catch is CancellationError {
                XCTAssertEqual(proxy.stopAdvertisingRegistry.subscriptions(), [])
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
    
    func testStopAdvertisingFailOnSingleTaskDueToTaskCancellationAsync() async throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Start advertising.
        try startAdvertising()
        // Check for monitor to be running.
        XCTAssertNotNil(blePeripheralManagerProxy.advertisingMonitor)
        // Mock delay
        blePeripheralManager.delayOnStopAdvertising = .seconds(2)
        // Begin test
        let proxy: BlePeripheralManagerProxy! = blePeripheralManagerProxy
        let started = XCTestExpectation(description: "Task started")
        started.expectedFulfillmentCount = 2
        let task1 = Task {
            started.fulfill() // Signal that the first task has started
            do {
                try await proxy.stopAdvertising()
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
                try await proxy.stopAdvertising()
                XCTAssertFalse(proxy.isAdvertising)
                XCTAssertEqual(proxy.stopAdvertisingRegistry.subscriptions(), [])
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
