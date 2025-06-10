//
//  BleCentralManagerProxyPeripheralRetrievalTests.swift
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

final class BleCentralManagerProxyPeripheralRetrievalTests: BlueConnectTests {
    
    // MARK: - Properties
    
    var blePeripheralProxy_1: BlePeripheralProxy!
    var blePeripheralProxy_2: BlePeripheralProxy!
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        blePeripheralProxy_1 = .init(peripheral: try blePeripheral_1)
        blePeripheralProxy_2 = .init(peripheral: try blePeripheral_2)
    }
    
    override func tearDownWithError() throws {
        blePeripheralProxy_1 = nil
        blePeripheralProxy_2 = nil
        try super.tearDownWithError()
    }
    
}

// MARK: - Test retrieve peripheral by identifier

extension BleCentralManagerProxyPeripheralRetrievalTests {
    
    func testRetrievePeripheralById() throws {
        let peripherals = bleCentralManagerProxy.retrievePeripherals(withIdentifiers: [MockBleDescriptor.peripheralUUID_1])
        XCTAssertEqual(peripherals.count, 1)
        XCTAssertTrue(peripherals.contains { $0.identifier == MockBleDescriptor.peripheralUUID_1 })
    }
    
    func testRetrievePeripheralsById() throws {
        let peripherals = bleCentralManagerProxy.retrievePeripherals(withIdentifiers: [
            MockBleDescriptor.peripheralUUID_1,
            MockBleDescriptor.peripheralUUID_2,
        ])
        XCTAssertEqual(peripherals.count, 2)
        XCTAssertTrue(peripherals.contains { $0.identifier == MockBleDescriptor.peripheralUUID_1 })
        XCTAssertTrue(peripherals.contains { $0.identifier == MockBleDescriptor.peripheralUUID_2 })
    }
    
    func testRetrieveNoPeripheralById() throws {
        let peripherals = bleCentralManagerProxy.retrievePeripherals(withIdentifiers: [])
        XCTAssertEqual(peripherals.count, 0)
    }
    
}

// MARK: - Test retrieve peripheral by service id

extension BleCentralManagerProxyPeripheralRetrievalTests {
    
    func testRetrieveConnectedPeripheralsByServiceIdWithCentralOff() throws {
        let peripherals = bleCentralManagerProxy.retrieveConnectedPeripherals(withServices: [MockBleDescriptor.deviceInformationServiceUUID])
        XCTAssertEqual(peripherals.count, 0)
    }
    
    func testRetrieveConnectedPeripheralsByServiceIdWithPeripheralDisconnected() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Retrieve connected peripherals
        let peripherals = bleCentralManagerProxy.retrieveConnectedPeripherals(withServices: [MockBleDescriptor.deviceInformationServiceUUID])
        XCTAssertEqual(peripherals.count, 0)
    }
    
    func testRetrieveConnectedPeripheralsByServiceIdWithUndiscoveredServices() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect just one peripheral
        connect(peripheral: try blePeripheral_2)
        // Retrieve connected peripherals
        let peripherals = bleCentralManagerProxy.retrieveConnectedPeripherals(withServices: [MockBleDescriptor.deviceInformationServiceUUID])
        XCTAssertEqual(peripherals.count, 0)
    }
    
    func testRetrieveConnectedPeripheralsByServiceIdWithUndiscoveredService() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect just one peripheral
        connect(peripheral: try blePeripheral_2)
        // Discover just one service but not the one we are looking for
        let expectation = expectation(description: "waiting for service to be discovered")
        blePeripheralProxy_2.discover(serviceUUID: MockBleDescriptor.heartRateServiceUUID) { result in
            switch result {
                case .success(let service):
                    XCTAssertEqual(service.uuid, MockBleDescriptor.heartRateServiceUUID)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("service discovery failed with error: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
        // Retrieve connected peripherals
        let peripherals = bleCentralManagerProxy.retrieveConnectedPeripherals(withServices: [MockBleDescriptor.deviceInformationServiceUUID])
        XCTAssertEqual(peripherals.count, 0)
    }
    
    func testRetrieveConnectedPeripheralsByServiceIdWithSingleConnectedPeripheral() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect just one peripheral
        connect(peripheral: try blePeripheral_2)
        // Discover just one service
        let expectation = expectation(description: "waiting for service to be discovered")
        blePeripheralProxy_2.discover(serviceUUID: MockBleDescriptor.deviceInformationServiceUUID) { result in
            switch result {
                case .success(let service):
                    XCTAssertEqual(service.uuid, MockBleDescriptor.deviceInformationServiceUUID)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("service discovery failed with error: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
        // Retrieve connected peripherals
        let peripherals = bleCentralManagerProxy.retrieveConnectedPeripherals(withServices: [MockBleDescriptor.deviceInformationServiceUUID])
        XCTAssertEqual(peripherals.count, 1)
        XCTAssertTrue(peripherals.contains { $0.identifier == MockBleDescriptor.peripheralUUID_2 })
    }
    
}
