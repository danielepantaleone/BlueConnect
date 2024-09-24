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
import CoreBluetooth
import Foundation
import XCTest

@testable import BlueConnect

final class BleCentralManagerProxyScanTests: BlueConnectTests {
 
    func testScanWithTimeout() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to be terminated")
        let publisherExp = expectation(description: "waiting for peripheral discovery to be signaled by publisher")
        publisherExp.expectedFulfillmentCount = 3
        publisherExp.assertForOverFulfill = false
        // Test discovery emit on publisher
        bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(4))
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
            .store(in: &subscriptions)
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 5.0)
        XCTAssertFalse(bleCentralManager.isScanning)
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
        bleCentralManagerProxy.scanForPeripherals(timeout: .never)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    completionExp.fulfill()
                },
                receiveValue: { _ in
                    publisherExp.fulfill()
                }
            )
            .store(in: &subscriptions)
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 5.0)
        XCTAssertTrue(bleCentralManager.isScanning)
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
        bleCentralManagerProxy.scanForPeripherals(timeout: .never)
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
                receiveValue: { record in
                    publisherExp.fulfill()
                }
            )
            .store(in: &subscriptions)
        // Manually stop the scan
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) { [weak self] in
            guard let self else { return }
            bleCentralManagerProxy.stopScan()
        }
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 5.0)
        XCTAssertTrue(bleCentralManager.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanFailDueToBleCentralManagerOff() throws {
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to terminate with failure")
        let publisherExp = expectation(description: "waiting for peripheral discovery NOT to be signaled by publisher")
        publisherExp.isInverted = true
        // Test discovery emit on publisher
        bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(2))
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
                            guard case .invalidState(let state) = proxyError.category else {
                                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError category 'invalidState', got '\(proxyError.category)' instead")
                                return
                            }
                            XCTAssertEqual(state, .poweredOff)
                            completionExp.fulfill()
                    }
                },
                receiveValue: { _ in
                    publisherExp.fulfill()
                }
            )
            .store(in: &subscriptions)
        // Await expectation
        wait(for: [completionExp, publisherExp], timeout: 3.0)
        XCTAssertFalse(bleCentralManager.isScanning)
        XCTAssertNil(bleCentralManagerProxy.discoverTimer)
        XCTAssertNil(bleCentralManagerProxy.discoverSubject)
    }
    
    func testScanFailDueToProxyDestroyed() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Test scan discovery
        let completionExp = expectation(description: "waiting for scan to terminate with failure")
        // Test discovery emit on publisher
        bleCentralManagerProxy.scanForPeripherals(timeout: .never)
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
                            guard case .destroyed = proxyError.category else {
                                XCTFail("peripheral discovery was expected to fail with BleCentralManagerProxyError category 'destroyed', got '\(proxyError.category)' instead")
                                return
                            }
                            completionExp.fulfill()
                    }
                },
                receiveValue: { _ in
                    
                }
            )
            .store(in: &subscriptions)
        // Destroy the proxy
        bleCentralManagerProxy = nil
        // Await expectation
        wait(for: [completionExp], timeout: 2.0)
        XCTAssertFalse(bleCentralManager.isScanning)
    }
    
}
