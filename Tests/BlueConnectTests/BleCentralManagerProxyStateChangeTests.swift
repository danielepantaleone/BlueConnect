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
import CoreBluetooth
import Foundation
import XCTest

@testable import BlueConnect
    
final class BleCentralManagerProxyStateChangeTests: BlueConnectTests {
    
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
        bleCentralManagerProxy.didDisconnectPublisher
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
            .store(in: &subscriptions)
        // Test connection failure publisher to be called on blePeripheral_2
        bleCentralManagerProxy.didFailToConnectPublisher
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
            .store(in: &subscriptions)
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
                    XCTAssertNil(bleCentralManagerProxy.connectionTimers[MockBleDescriptor.peripheralUUID_1])
                    connectExp.fulfill()
            }
        }
        // Wait a bit before turning off central manager.
        wait(.seconds(2))
        // Turn off ble central manager
        centralManager(state: .poweredOff)
        // Await expectations
        wait(for: [connectExp, connectFailPublisherExp, disconnectPublisherExp], timeout: 6.0)
        XCTAssertEqual(try blePeripheral_1.state, .disconnected)
        XCTAssertEqual(try blePeripheral_2.state, .disconnected)
        XCTAssertEqual(bleCentralManagerProxy.connectionState[MockBleDescriptor.peripheralUUID_1], .disconnected)
        XCTAssertEqual(bleCentralManagerProxy.connectionState[MockBleDescriptor.peripheralUUID_2], .disconnected)
        XCTAssertEqual(bleCentralManagerProxy.connectionTimeouts.count, 0 )
    }
    
}
