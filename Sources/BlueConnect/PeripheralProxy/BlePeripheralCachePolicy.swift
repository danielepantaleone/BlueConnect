//
//  BlePeripheralCachePolicy.swift
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

import Dispatch

/// An enum that defines policies for caching values read from a `BlePeripheral`.
///
/// The `BlePeripheralCachePolicy` enum specifies different strategies for determining whether to retrieve a value from the cache or fetch it directly from the peripheral.
/// This helps optimize communication with Bluetooth hardware by reducing unnecessary requests when cached data is available and valid.
public enum BlePeripheralCachePolicy: Sendable {
    
    /// Never use the cached value and always fetch the latest data from the peripheral.
    case never
    
    /// Always use the cached value if present, regardless of its age.
    case always
    
    /// Use the cached value if present and not older than the specified time interval; otherwise, fetch a real-time value from the peripheral.
    ///
    /// - Parameter timeInterval: The maximum time interval for which the cached value is considered valid.
    case timeSensitive(DispatchTimeInterval)

    // MARK: - Functions
    
    /// Determines whether the cached data is still valid based on the cache policy.
    ///
    /// - Parameter time: The time the cache was last updated, defaults to the current time.
    /// - Returns: `true` if the cached data is valid according to the cache policy, `false` otherwise.
    public func isValid(time: DispatchTime = .now()) -> Bool {
        switch self {
            case .never:
                return false
            case .always:
                return true
            case .timeSensitive(let timeInterval):
                return time.distance(to: .now()) < timeInterval
        }
    }
    
}
