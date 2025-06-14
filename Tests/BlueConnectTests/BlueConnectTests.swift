//
//  BlueConnectTests.swift
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

class BlueConnectTests: XCTestCase {
    
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
    var blePeripheral_2: MockBlePeripheral {
        get throws {
            let peripheralId = try XCTUnwrap(MockBleDescriptor.peripheralUUID_2)
            let peripheral = bleCentralManager.retrievePeripherals(withIds: [peripheralId]).first
            return try XCTUnwrap(peripheral as? MockBlePeripheral)
        }
    }
    var blePeripheralManager: MockBlePeripheralManager!
    var blePeripheralManagerProxy: BlePeripheralManagerProxy!
    let queue: DispatchQueue = DispatchQueue.global(qos: .background)
    
    // MARK: - Setup & tear down
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        bleCentralManager = .init(peripherals: [
            MockBlePeripheral(
                identifier: MockBleDescriptor.peripheralUUID_1,
                name: nil,
                serialNumber: "12345678",
                batteryLevel: 77,
                firmwareRevision: "1.0.7",
                hardwareRevision: "2.0.4",
                secret: "abcd"),
            MockBlePeripheral(
                identifier: MockBleDescriptor.peripheralUUID_2,
                name: "PERIPHERAL_2",
                serialNumber: "87654321",
                batteryLevel: 43,
                firmwareRevision: "1.0.2",
                hardwareRevision: "2.0.1",
                secret: "efgh")
        ])
        bleCentralManagerProxy = .init(centralManager: bleCentralManager)
        blePeripheralManager = .init()
        blePeripheralManagerProxy = .init(peripheralManager: blePeripheralManager)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        bleCentralManagerProxy = nil
        bleCentralManager = nil
        blePeripheralManagerProxy = nil
        blePeripheralManager = nil
    }
    
    // MARK: - Functions
    
    func centralManager(state: CBManagerState) {
        XCTAssertNotEqual(bleCentralManager.state, state)
        let expectation = expectation(description: "waiting for bluetooth central manager state to change to '\(state)'")
        let subscription = bleCentralManagerProxy.didUpdateStatePublisher
            .receive(on: DispatchQueue.global())
            .filter { $0 == state }
            .sink { _ in expectation.fulfill() }
        bleCentralManager.state = state
        wait(for: [expectation], timeout: 2.0)
        subscription.cancel()
    }
    
    func peripheralManager(state: CBManagerState) {
        XCTAssertNotEqual(blePeripheralManager.state, state)
        let expectation = expectation(description: "waiting for bluetooth peripheral manager state to change to '\(state)'")
        let subscription = blePeripheralManagerProxy.didUpdateStatePublisher
            .receive(on: DispatchQueue.global())
            .filter { $0 == state }
            .sink { _ in expectation.fulfill() }
        blePeripheralManager.state = state
        wait(for: [expectation], timeout: 2.0)
        subscription.cancel()
    }
    
    func connect(peripheral: BlePeripheral) {
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        XCTAssertNotEqual(peripheral.state, .connected)
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
    
    func disconnect(peripheral: BlePeripheral) {
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        XCTAssertNotEqual(peripheral.state, .disconnected)
        let expectation = expectation(description: "waiting for peripheral to disconnect")
        bleCentralManagerProxy.disconnect(peripheral: peripheral) { result in
            switch result {
                case .success:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("peripheral disconnection failed with error: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(peripheral.state, .disconnected)
    }
    
    func discover(serviceUUID: CBUUID, on proxy: BlePeripheralProxy) {
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        XCTAssertEqual(proxy.peripheral.state, .connected)
        XCTAssertNil(proxy.getService(serviceUUID))
        let expectation = expectation(description: "waiting for service to be discovered")
        proxy.discover(serviceUUID: serviceUUID, timeout: .never) { result in
            switch result {
                case .success(let service):
                    XCTAssertEqual(service.uuid, serviceUUID)
                    XCTAssertNotNil(proxy.getService(serviceUUID))
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("service discovery failed with error: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    func discover(characteristicUUID: CBUUID, in serviceUUID: CBUUID, on proxy: BlePeripheralProxy) {
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        XCTAssertEqual(proxy.peripheral.state, .connected)
        XCTAssertNotNil(proxy.getService(serviceUUID))
        XCTAssertNil(proxy.getCharacteristic(characteristicUUID))
        let expectation = expectation(description: "waiting for characteristic to be discovered")
        proxy.discover(characteristicUUID: characteristicUUID, in: serviceUUID, timeout: .never) { result in
            switch result {
                case .success(let characteristic):
                    XCTAssertEqual(characteristic.uuid, characteristicUUID)
                    XCTAssertNotNil(proxy.getCharacteristic(characteristicUUID))
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("characteristic discovery failed with error: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    @discardableResult
    func read(characteristicUUID: CBUUID, on proxy: BlePeripheralProxy) throws -> Data {
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        XCTAssertEqual(proxy.peripheral.state, .connected)
        XCTAssertNotNil(proxy.getCharacteristic(characteristicUUID))
        let expectation = expectation(description: "waiting for characteristic to be read")
        var characteristicData: Data? = nil
        proxy.read(
            characteristicUUID: characteristicUUID,
            cachePolicy: .never,
            timeout: .never
        ) { result in
            switch result {
                case .success(let data):
                    characteristicData = data
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("characteristic read failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 2.0)
        // Return read data
        guard let characteristicData else {
            throw MockBleError.characteristicNotRead
        }
        return characteristicData
    }
    
    func setNotify(characteristicUUID: CBUUID, enabled: Bool, on proxy: BlePeripheralProxy) {
        XCTAssertEqual(bleCentralManager.state, .poweredOn)
        XCTAssertEqual(proxy.peripheral.state, .connected)
        XCTAssertNotNil(proxy.getCharacteristic(characteristicUUID))
        let expectation = expectation(description: "waiting for characteristic notify to be enabled")
        proxy.setNotify(
            enabled: enabled,
            for: characteristicUUID,
            timeout: .never
        ) { result in
            switch result {
                case .success(let enabled):
                    XCTAssertTrue(enabled)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("characteristic set notify failed with error: \(error)")
            }
        }
        // Await expectations
        wait(for: [expectation], timeout: 12.0)
    }
    
    func startAdvertising() throws {
        XCTAssertEqual(blePeripheralManagerProxy.state, .poweredOn)
        XCTAssertFalse(blePeripheralManagerProxy.isAdvertising)
        let expectation = expectation(description: "waiting for peripheral manager advertising to start")
        blePeripheralManagerProxy.startAdvertising { result in
            switch result {
                case .success:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("waiting for peripheral manager advertising to start failed with error: \(error)")
            }
        }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(blePeripheralManagerProxy.isAdvertising)
    }
    
    func wait(_ timeout: DispatchTimeInterval) {
        let expectation = expectation(description: "waiting")
        let queue = DispatchQueue.global(qos: .background)
        queue.asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: (TimeInterval(timeout.nanoseconds) * 1_000_000_000.0) + 0.5)
    }
    
}
