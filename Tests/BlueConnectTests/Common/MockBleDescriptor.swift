//
//  MockBleDescriptor.swift
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

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

@testable import BlueConnect

enum MockBleDescriptor {
    
    // MARK: - Device information service
    
    static let deviceInformationServiceUUID = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
    static let serialNumberCharacteristicUUID = CBUUID(string: "00002A25-0000-1000-8000-00805F9B34FB")
    static let firmwareRevisionCharacteristicUUID = CBUUID(string: "00002A26-0000-1000-8000-00805F9B34FB")
    static let hardwareRevisionCharacteristicUUID = CBUUID(string: "00002A27-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Battery service
    
    static let batteryServiceUUID = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
    static let batteryLevelCharacteristicUUID = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Heart rate service
    
    static let heartRateServiceUUID = CBUUID(string: "0000180D-0000-1000-8000-00805F9B34FB")
    static let heartRateCharacteristicUUID = CBUUID(string: "00002A37-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Custom service

    static let customServiceUUID = CBUUID(string: "C5405A74-7C07-4702-A631-9D5EBF007DAE")
    static let secretCharacteristicUUID = CBUUID(string: "5A8F2E01-58D9-4B0B-83B8-843402E49293")
    static let bufferCharacteristicUUID = CBUUID(string: "5A8F2E02-58D9-4B0B-83B8-843402E49293")
    
    // MARK: - Peripherals
    
    static let peripheralUUID_1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let peripheralUUID_2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    
}
