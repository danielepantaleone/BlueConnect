//
//  AtomicReference.swift
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

/// A thread-safe atomic reference for storing and updating values of a `Sendable` type.
///
/// This class ensures safe concurrent access to the stored value by using an `NSLock`.
/// It provides atomic get and set operations.
final class AtomicReference<ValueType: Sendable>: @unchecked Sendable {
    
    // MARK: - Private Properties
    
    /// The internally stored reference value.
    private var reference: ValueType
    
    /// A lock to ensure thread-safe access to the reference.
    private let lock: NSLock = .init()
    
    // MARK: - Properties
    
    /// The current value of the atomic reference.
    ///
    /// - Note: Access to this property is thread-safe.
    var value: ValueType {
        get { lock.withLock { reference } }
        set { lock.withLock { reference = newValue } }
    }
    
    // MARK: - Initialization
    
    /// Creates an atomic reference with an initial value.
    ///
    /// - Parameter value: The initial value to store.
    init(_ value: ValueType) {
        self.reference = value
    }
    
}
