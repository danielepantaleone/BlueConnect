//
//  BleCentralManagerProxy+Retrieval.swift
//  BlueConnect
//
//  GitHub Repo and Documentation: https://github.com/danielepantaleone/BlueConnect
//
//  Copyright © 2025 Daniele Pantaleone. All rights reserved.
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

extension BleCentralManagerProxy {
    
    /// Retrieves all peripherals that are connected to the system and implement any of the services listed in serviceUUIDs.
    ///
    /// This method returns peripherals that are currently connected to the system and offer specific services.
    ///
    /// - Parameter serviceUUIDs: A list of service UUIDs (represented by `CBUUID` objects) to filter connected peripherals.
    /// - Returns: A list of objects implementing the `BlePeripheral` protocol.
    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [BlePeripheral] {
        return centralManager.retrieveConnectedPeripherals(withServiceIds: serviceUUIDs)
    }
    
    /// Retrieve all the peripherals with the corresponding identifiers.
    ///
    /// This method retrieves previously connected peripherals with specific identifiers.
    ///
    /// - Parameter identifiers: A list of peripheral identifiers (represented by `UUID` objects) from which peripheral objects can be retrieved.
    /// - Returns: A list of objects implementing the `BlePeripheral` protocol.
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [BlePeripheral] {
        return centralManager.retrievePeripherals(withIds: identifiers)
    }
    
}
