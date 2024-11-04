//
//  BlePeripheralProxyTests.swift
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

final class BlePeripheralProxyTests: BlueConnectTests {
    
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
        try super.tearDownWithError()
    }
    
}

// MARK: - Name update tests

extension BlePeripheralProxyTests {
    
    func testPeripheralNameUpdate() throws {
        // Turn on ble central manager
        centralManager(state: .poweredOn)
        // Connect the peripheral
        connect(peripheral: try blePeripheral_2)
        // Test name update
        let expectation = expectation(description: "waiting for peripheral name update to be signaled by publisher")
        blePeripheralProxy_2.didUpdateNamePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0 == "YODA" }
            .sink { _ in expectation.fulfill() }
            .store(in: &subscriptions)
        // Change the name
        try blePeripheral_2.setName("YODA", after: .seconds(2))
        // Await expectations
        wait(for: [expectation], timeout: 4.0)
    }
    
}
