//
//  RecursiveCondition.swift
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

class RecursiveCondition: RecursiveMutex {
    
    // MARK: - Properties
    
    var condition = pthread_cond_t()
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        var attr = pthread_condattr_t()
        pthread_condattr_init(&attr)
        pthread_cond_init(&condition, &attr)
        pthread_condattr_destroy(&attr)
    }
    
    deinit {
        pthread_cond_destroy(&condition)
    }
    
    // MARK: - Interface
    
    @inline(__always)
    public func signal() {
        pthread_cond_signal(&condition)
    }
    
    @inline(__always)
    public func broadcast() {
        pthread_cond_broadcast(&condition)
    }
    
    @inline(__always)
    public func wait() {
        pthread_cond_wait(&condition, &mutex)
    }
    
    @discardableResult
    @inline(__always)
    public func wait(timeout: TimeInterval) -> Bool {
        return wait(until: Date(timeIntervalSinceNow: timeout))
    }
    
    @discardableResult
    @inline(__always)
    public func wait(until date: Date) -> Bool {
        let time = date.timeIntervalSince1970
        var expire = timespec()
        expire.tv_sec = __darwin_time_t(time)
        expire.tv_nsec = (Int(time) - expire.tv_sec) * 1_000_000_000
        return pthread_cond_timedwait(&condition, &mutex, &expire) == 0
    }
    
}
