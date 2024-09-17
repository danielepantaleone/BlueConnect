//
//  BlePeripheralCacheRecord.swift
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

import Foundation

/// A struct that holds the value read from a `BlePeripheral`, cached locally to reduce communication with the Bluetooth hardware device.
///
/// The cached data can be reused according to the provided `BlePeripheralCachePolicy`, avoiding unnecessary BLE communication for data that doesn't change frequently over time.
/// This struct stores both the cached data and the time when it was cached, allowing for cache expiration logic based on time intervals.
///
/// - Note: This is useful for optimizing performance and reducing BLE interactions when retrieving static or infrequently changing data.
public struct BlePeripheralCacheRecord {
    
    /// The data cached from the BLE peripheral.
    public let data: Data
    /// The time when the data was cached. This helps in determining whether the cache is still valid based on `BlePeripheralCachePolicy`.
    public let time: DispatchTime
    
    /// Initializes a new BLE peripheral cache record with the given data and optional cache time.
    ///
    /// - Parameters:
    ///   - data: The data to be cached.
    ///   - time: The time when the data is cached. Defaults to the current time (`DispatchTime.now()`).
    public init(data: Data, time: DispatchTime = .now()) {
        self.data = data
        self.time = time
    }
    
}
