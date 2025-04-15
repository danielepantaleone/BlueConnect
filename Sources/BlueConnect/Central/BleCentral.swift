//
//  BleCentral.swift
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

@preconcurrency import CoreBluetooth

/// A protocol to mimic the capabilities of a `CBCentral`.
///
/// This protocol can be adopted by mock objects to simulate BLE central behavior in tests, enabling controlled and repeatable testing of BLE operations without requiring a physical device.
///
/// - Note: `CBCentral` conforms to `BleCentral`.
public protocol BleCentral: AnyObject {
    
    /// The unique identifier of the BLE central.
    ///
    /// Each BLE central has a unique identifier that can be used to distinguish it from other devices.
    var identifier: UUID { get }
    
    /// The maximum amount of data, in bytes, that the central can receive in a single notification or indication.
    ///
    /// This value represents the central’s maximum limit for data transfer, which may vary depending on the device capabilities.
    var maximumUpdateValueLength: Int { get }
    
}

extension CBCentral: BleCentral {
    
}
