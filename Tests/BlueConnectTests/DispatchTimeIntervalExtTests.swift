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
import CoreBluetooth
import Foundation
import XCTest

@testable import BlueConnect

class DispatchTimeIntervalExtTests: XCTestCase {
    
    func testSecondsAdd() {
        let x: DispatchTimeInterval = .seconds(4)
        let y: DispatchTimeInterval = .seconds(3)
        XCTAssertEqual(x + y, .seconds(7))
    }
    
    func testSecondsAddMilliseconds() {
        let x: DispatchTimeInterval = .seconds(4)
        let y: DispatchTimeInterval = .milliseconds(3000)
        XCTAssertEqual(x + y, .seconds(7))
    }
    
    func testSecondsSubtract() {
        let x: DispatchTimeInterval = .seconds(4)
        let y: DispatchTimeInterval = .seconds(3)
        XCTAssertEqual(x - y, .seconds(1))
    }
    
    func testMillisecondsAdd() {
        let x: DispatchTimeInterval = .milliseconds(400)
        let y: DispatchTimeInterval = .milliseconds(300)
        XCTAssertEqual(x + y, .milliseconds(700))
    }
    
    func testMillisecondsAddMicroseconds() {
        let x: DispatchTimeInterval = .milliseconds(400)
        let y: DispatchTimeInterval = .microseconds(300000)
        XCTAssertEqual(x + y, .milliseconds(700))
    }
    
    func testMillisecondsSubtract() {
        let x: DispatchTimeInterval = .milliseconds(400)
        let y: DispatchTimeInterval = .milliseconds(300)
        XCTAssertEqual(x - y, .milliseconds(100))
    }
    
    func testMillisecondsSubtractNever() {
        let x: DispatchTimeInterval = .milliseconds(400)
        let y: DispatchTimeInterval = .never
        XCTAssertEqual(x - y, .never)
    }
    
    func testMicrosecondsAdd() {
        let x: DispatchTimeInterval = .microseconds(400)
        let y: DispatchTimeInterval = .microseconds(300)
        XCTAssertEqual(x + y, .microseconds(700))
    }
    
    func testMicrosecondsAddNanoseconds() {
        let x: DispatchTimeInterval = .microseconds(400)
        let y: DispatchTimeInterval = .nanoseconds(300000)
        XCTAssertEqual(x + y, .microseconds(700))
    }
    
    func testMicrosecondsAddNever() {
        let x: DispatchTimeInterval = .microseconds(400)
        let y: DispatchTimeInterval = .never
        XCTAssertEqual(x + y, .never)
    }
    
    func testMicrosecondsSubtract() {
        let x: DispatchTimeInterval = .microseconds(400)
        let y: DispatchTimeInterval = .microseconds(300)
        XCTAssertEqual(x - y, .microseconds(100))
    }
    
    func testNeverToMaxNanoseconds() {
        let x: DispatchTimeInterval = .never
        XCTAssertEqual(x.nanoseconds, Int.max)
    }
    
    func testCompareMilliseconds() {
        let x: DispatchTimeInterval = .milliseconds(400)
        let y: DispatchTimeInterval = .milliseconds(300)
        XCTAssertTrue(x > y)
    }
    
    func testCompareMillisecondsAndMicroseconds() {
        let x: DispatchTimeInterval = .microseconds(400)
        let y: DispatchTimeInterval = .milliseconds(300)
        XCTAssertTrue(x < y)
    }
    
}

