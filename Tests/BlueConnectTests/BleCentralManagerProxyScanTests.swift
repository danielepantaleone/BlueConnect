//
//  BleCentralManagerProxyScanTests.swift
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

final class BleCentralManagerProxyScanTests: BlueConnectTests {
    
}

// MARK: - Test scan

@MainActor
extension BleCentralManagerProxyScanTests {
 
    func testScanWithTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to be terminated")
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.assertForOverFulfill = false
        // Test discovery emit on publisher
        let subscription = bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(2))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    switch completion {
                        case .finished:
                            XCTAssertFalse(bleCentralManagerProxy.isScanning)
                            completionExp.fulfill()
                        case .failure(let error):
                            XCTFail("peripheral discovery terminated with error: \(error)")
                    }
                },
                receiveValue: { _ in
                    publisherExp.fulfill()
                }
            )
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 4.0)
        subscription.cancel()
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanWithNoTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan NOT to be terminated")
        completionExp.isInverted = true
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.expectedFulfillmentCount = 3
        publisherExp.assertForOverFulfill = false
        // Test discovery emit on publisher
        let subscription = bleCentralManagerProxy.scanForPeripherals(timeout: .never)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    completionExp.fulfill()
                },
                receiveValue: { _ in
                    publisherExp.fulfill()
                }
            )
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 5.0)
        subscription.cancel()
        XCTAssertTrue(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNotNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanWithNoTimeoutManuallyStopped() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to be terminated")
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.expectedFulfillmentCount = 3
        publisherExp.assertForOverFulfill = false
        // Test discovery emit on publisher
        let subscription = bleCentralManagerProxy.scanForPeripherals(timeout: .never)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                        case .finished:
                            completionExp.fulfill()
                        case .failure(let error):
                            XCTFail("peripheral discovery terminated with error: \(error)")
                    }
                },
                receiveValue: { _ in
                    publisherExp.fulfill()
                }
            )
        // Manually stop the scan in 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) { [weak self] in
            self?.bleCentralManagerProxy.stopScan()
        }
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 5.0)
        subscription.cancel()
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanFailDueToBleCentralManagerOff() throws {
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to terminate with failure")
        let publisherExp = expectation(description: "waiting for peripheral discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test discovery emit on publisher
        let subscription = bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(2))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    switch completion {
                        case .finished:
                            XCTFail("peripheral discovery terminated with success but failure was expected")
                        case .failure(let error):
                            guard let proxyError = error as? BleCentralManagerProxyError else {
                                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                                return
                            }
                            guard case .invalidState(let state) = proxyError else {
                                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                                return
                            }
                            XCTAssertEqual(state, .poweredOff)
                            XCTAssertFalse(bleCentralManagerProxy.isScanning)
                            completionExp.fulfill()
                    }
                },
                receiveValue: { _ in
                    publisherExp.fulfill()
                }
            )
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 3.0)
        subscription.cancel()
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to terminate with failure")
        // Test discovery emit on publisher
        let subscription = bleCentralManagerProxy.scanForPeripherals(timeout: .never)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                        case .finished:
                            XCTFail("peripheral discovery terminated with success but failure was expected")
                        case .failure(let error):
                            guard let proxyError = error as? BleCentralManagerProxyError else {
                                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                                return
                            }
                            guard case .destroyed = proxyError else {
                                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError 'destroyed', got '\(proxyError)' instead")
                                return
                            }
                            completionExp.fulfill()
                    }
                },
                receiveValue: { _ in
                    
                }
            )
        // Check that we are scanning
        XCTAssertTrue(bleCentralManagerProxy.isScanning)
        // Destroy the proxy
        bleCentralManagerProxy = nil
        // Await expectation
        wait(for: [completionExp], timeout: 2.0)
        subscription.cancel()
        XCTAssertFalse(bleCentralManager.isScanning)
    }
    
}

// MARK: - Test scan (async)

@MainActor
extension BleCentralManagerProxyScanTests {
    
    func testScanWithTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to be terminated")
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.assertForOverFulfill = false
        do {
            for try await _ in bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(2)) {
                publisherExp.fulfill()
            }
            completionExp.fulfill()
        } catch {
            XCTFail("peripheral discovery terminated with error: \(error)")
        }
        await fulfillment(of: [completionExp, publisherExp], timeout: 4.0)
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanWithNoTimeoutAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        var counter = 0
        let completionExp = expectation(description: "waiting for scan to be terminated")
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.assertForOverFulfill = false
        do {
            for try await _ in bleCentralManagerProxy.scanForPeripherals(timeout: .never) {
                counter += 1
                publisherExp.fulfill()
                if counter > 2 {
                    break
                }
            }
            completionExp.fulfill()
        } catch {
            XCTFail("peripheral discovery terminated with error: \(error)")
        }
        await fulfillment(of: [completionExp, publisherExp], timeout: 5.0)
        // We assert like it's finished because of the termination handling in the async stream
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanWithNoTimeoutManuallyStoppedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to be terminated")
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.assertForOverFulfill = false
        // Manually stop the scan in 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) { [weak self] in
            self?.bleCentralManagerProxy.stopScan()
        }
        do {
            for try await _ in bleCentralManagerProxy.scanForPeripherals(timeout: .never) {
                publisherExp.fulfill()
            }
            completionExp.fulfill()
        } catch {
            XCTFail("peripheral discovery terminated with error: \(error)")
        }
        await fulfillment(of: [completionExp, publisherExp], timeout: 5.0)
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanWithNoTimeoutStoppedByTaskCancellationAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to be terminated")
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.assertForOverFulfill = false
        let task = Task {
            do {
                for try await _ in bleCentralManagerProxy.scanForPeripherals(timeout: .never) {
                    publisherExp.fulfill()
                }
                completionExp.fulfill()
            } catch {
                XCTFail("peripheral discovery terminated with error: \(error)")
            }
        }
        // Manually cancel the task in 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            task.cancel()
        }
        await fulfillment(of: [completionExp, publisherExp], timeout: 5.0)
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanFailDueToBleCentralManagerOffAsync() async throws {
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to terminate with failure")
        let publisherExp = expectation(description: "waiting for peripheral discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        do {
            for try await _ in bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(2)) {
                publisherExp.fulfill()
            }
            XCTFail("peripheral discovery terminated with success but failure was expected")
        } catch {
            guard let proxyError = error as? BleCentralManagerProxyError else {
                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                return
            }
            guard case .invalidState(let state) = proxyError else {
                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError 'invalidState', got '\(proxyError)' instead")
                return
            }
            XCTAssertEqual(state, .poweredOff)
            XCTAssertFalse(bleCentralManagerProxy.isScanning)
            completionExp.fulfill()
        }
    
        // Await expectation
        await fulfillment(of: [completionExp, publisherExp], timeout: 5.0)
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanFailDueToProxyDestroyedAsync() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Destroy the proxy
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
            self?.bleCentralManagerProxy = nil
        }
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to terminate with failure")
        // Test discovery stopped
        do {
            for try await _ in bleCentralManagerProxy.scanForPeripherals(timeout: .never) {
                // PASS
            }
            XCTFail("peripheral discovery terminated with success but failure was expected")
        } catch {
            guard let proxyError = error as? BleCentralManagerProxyError else {
                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError, got '\(error)' instead")
                return
            }
            guard case .destroyed = proxyError else {
                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError 'destroyed', got '\(proxyError)' instead")
                return
            }
            completionExp.fulfill()
        }
        // Await expectation
        await fulfillment(of: [completionExp], timeout: 4.0)
        XCTAssertFalse(bleCentralManager.isScanning)
    }
    
    func testScanFailDueToTaskCancellation() async throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Begin test
        let scan = expectation(description: "Peripheral discovered")
        scan.assertForOverFulfill = false
        let started = XCTestExpectation(description: "Task started")
        let task = Task {
            let startDate = Date()
            started.fulfill() // Signal that the task has started
            do {
                for try await _ in bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(10)) {
                    scan.fulfill()
                }
                let elapsed = Date().timeIntervalSince(startDate)
                XCTAssertLessThan(elapsed, 10)
            } catch is CancellationError {
                // Expected path #2
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
        // Wait for the task to begin.
        await fulfillment(of: [started], timeout: 1.0)
        // Wait for a first discovered peripheral
        await fulfillment(of: [scan], timeout: 4.0)
        // Now cancel the task.
        task.cancel()
        // Await the task to ensure cleanup.
        _ = await task.result
        // Assert final state
        XCTAssertFalse(bleCentralManagerProxy.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
}
