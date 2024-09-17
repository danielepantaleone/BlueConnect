//
//  DispatchTimeIntervalExtensions.swift
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

// MARK: - DispatchTimeInterval + Nanoseconds

extension DispatchTimeInterval {
    
    /// Converts the `DispatchTimeInterval` to nanoseconds.
    ///
    /// This property converts time intervals of seconds, milliseconds, microseconds, and nanoseconds into a common unit (nanoseconds).
    /// If the case is `.never`, it returns the maximum possible integer value (`Int.max`).
    ///
    /// - Returns: The equivalent value of the time interval in nanoseconds.
    var nanoseconds: Int {
        switch self {
            case .seconds(let seconds):
                return seconds * 1_000_000_000
            case .milliseconds(let milliseconds):
                return milliseconds * 1_000_000
            case .microseconds(let microseconds):
                return microseconds * 1_000
            case .nanoseconds(let nanoseconds):
                return nanoseconds
            case .never:
                return .max
            @unknown default:
                return .max
        }
    }
    
}

// MARK: - DispatchTimeInterval + Operators

extension DispatchTimeInterval {
    
    /// Adds two `DispatchTimeInterval` values together.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `DispatchTimeInterval`.
    ///   - rhs: The right-hand side `DispatchTimeInterval`.
    /// - Returns: A new `DispatchTimeInterval` representing the sum of the two intervals. If either value is `.never`, the result is `.never`.
    static func + (lhs: Self, rhs: Self) -> Self {
        guard lhs != .never && rhs != .never else {
            return .never
        }
        return .nanoseconds(lhs.nanoseconds + rhs.nanoseconds)
    }
    
    /// Subtracts one `DispatchTimeInterval` value from another.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `DispatchTimeInterval`.
    ///   - rhs: The right-hand side `DispatchTimeInterval`.
    /// - Returns: A new `DispatchTimeInterval` representing the difference between the two intervals. If either value is `.never`, the result is `.never`.
    static func - (lhs: Self, rhs: Self) -> Self {
        guard lhs != .never && rhs != .never else {
            return .never
        }
        return .nanoseconds(lhs.nanoseconds - rhs.nanoseconds)
    }
    
}

// MARK: - DispatchTimeInterval + Comparable

extension DispatchTimeInterval: @retroactive Comparable {
    
    /// Compares two `DispatchTimeInterval` values.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `DispatchTimeInterval`.
    ///   - rhs: The right-hand side `DispatchTimeInterval`.
    /// - Returns: `true` if the left-hand side is less than the right-hand side, based on their nanosecond values.
    public static func < (lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> Bool {
        return lhs.nanoseconds < rhs.nanoseconds
    }
    
}
