//
//  BlePeripheralInteractor.swift
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

import CoreBluetooth
import Foundation

public class BlePeripheralInteractor: NSObject {
    
    // MARK: - Public properties
    
    public let peripheral: BlePeripheral
    
    // MARK: - Internal properties
    
    var cache: [CBUUID: BlePeripheralCacheRecord] = [:]
    let mutex = RecursiveMutex()
    
    var characteristicReadTimers: [CBUUID: DispatchSourceTimer] = [:]
    var characteristicReadCallbacks: [CBUUID: [(Result<Data, Error>) -> Void]] = [:]
    var characteristicNotifyTimers: [CBUUID: DispatchSourceTimer] = [:]
    var characteristicNotifyCallbacks: [CBUUID: [(Result<Bool, Error>) -> Void]] = [:]
    var characteristicWriteTimers: [CBUUID: DispatchSourceTimer] = [:]
    var characteristicWriteCallbacks: [CBUUID: [(Result<Void, Error>) -> Void]] = [:]
    var characteristicDiscoverTimers: [CBUUID: DispatchSourceTimer] = [:]
    var characteristicDiscoverCallbacks: [CBUUID: [(Result<CBCharacteristic, Error>) -> Void]] = [:]
    var serviceDiscoverTimers: [CBUUID: DispatchSourceTimer] = [:]
    var serviceDiscoverCallbacks: [CBUUID: [(Result<CBService, Error>) -> Void]] = [:]

    // MARK: - Initialization
    
    public override init() {
        fatalError("use init(peripheral: BlePeripheral)")
    }
    
    public init(peripheral: BlePeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral.peripheralDelegate = self
    }
    
}

// MARK: - BlePeripheralInteractor + BlePeripheralDelegate

extension BlePeripheralInteractor: BlePeripheralDelegate {
    
}
