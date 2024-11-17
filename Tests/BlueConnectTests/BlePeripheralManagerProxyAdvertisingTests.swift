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
@preconcurrency import CoreBluetooth
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
        blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
        // Assert final state.
        XCTAssertTrue(blePeripheralManagerProxy.isAdvertising)
    }
    
    func testStartAdvertisingFailDueToPeripheralManagerOff() throws {
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to fail")
        let publisherExp = expectation(description: "waiting for peripheral manager advertising NOT to be emitted on publisher")
        publisherExp.isInverted = true
        // Assert over publisher notify.
        blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
        // Assert final state
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
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
        blePeripheralManager.delayOnAdvertising = .seconds(10)
        // Assert over publisher notify.
        blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherExp.fulfill() }
            .store(in: &subscriptions)
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
        // Assert final state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
    }
    
    func testStartAdvertisingFailDueToError() throws {
        // Turn on ble peripheral manager.
        peripheralManager(state: .poweredOn)
        // Assert initial advertising state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        // Await state change.
        let callbackExp = expectation(description: "waiting for peripheral manager advertising to fail")
        let publisherStartExp = expectation(description: "waiting for peripheral manager advertising NOT to be emitted on publisher")
        publisherStartExp.isInverted = true
        let publisherFailExp = expectation(description: "waiting for peripheral manager advertising fail to be emitted on publisher")
        // Mock advertising timeout.
        blePeripheralManager.errorOnAdvertising = MockBleError.mockedError
        // Assert over publisher notify.
        blePeripheralManagerProxy.didUpdateAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .sink { _ in publisherStartExp.fulfill() }
            .store(in: &subscriptions)
        blePeripheralManagerProxy.didFailToStartAdvertisingPublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in publisherFailExp.fulfill() }
            .store(in: &subscriptions)
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
        wait(for: [callbackExp, publisherStartExp, publisherFailExp], timeout: 2.0)
        // Assert final state.
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
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
        blePeripheralManager.delayOnAdvertising = .seconds(10)
        // Test timeout
        do {
            try await blePeripheralManagerProxy.startAdvertising(timeout: .seconds(2))
        } catch BlePeripheralManagerProxyError.advertisingTimeout {
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
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
        blePeripheralManager.errorOnAdvertising = MockBleError.mockedError
        // Test timeout
        do {
            try await blePeripheralManagerProxy.startAdvertising(timeout: .seconds(2))
        } catch MockBleError.mockedError {
            XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        } catch {
            XCTFail("peripheral manager advertising start was expected to fail with MockBleError.mockedError, got '\(error)' instead")
        }
    }
    
}
