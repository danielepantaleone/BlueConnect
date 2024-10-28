//
//  Locking.swift
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

// MARK: - Atomic property wrapper

/// A property wrapper that provides atomic access to a wrapped value using a mutex.
///
/// This wrapper ensures that reads and writes to the wrapped value are thread-safe by using a
/// mutex to synchronize access. It is useful in concurrent programming where multiple threads
/// may access the same property, preventing data races and ensuring consistency.
///
/// - Parameter ValueType: The type of the value to be wrapped. This can be any type that is not inherently thread-safe.
@propertyWrapper
class Atomic<ValueType> {
    
    /// The mutex used for read/write access.
    private let mutex: RecursiveMutex
    /// The wrapped value
    private var value: ValueType
    
    /// The projected value, which returns the wrapper itself for access to its functions.
    var projectedValue: Atomic<ValueType> {
        return self
    }
    
    /// Wraps a property around a mutex for atomic access.
    ///
    /// - Parameters:
    ///   - wrappedValue: The value to protect with the mutex.
    ///   - mutex: The mutex used to protect the wrapped value.
    init(wrappedValue: ValueType, mutex: RecursiveMutex = RecursiveMutex()) {
        self.value = wrappedValue
        self.mutex = mutex
    }
    
    /// The value wrapped within the mutex.
    ///
    /// - Returns: The current value of the wrapped property, synchronized for read access.
    /// - Parameter newValue: The new value to set for the wrapped property, synchronized for write access.
    var wrappedValue: ValueType {
        get { mutex.withLock { value } }
        set { mutex.withLock { value = newValue } }
    }
    
    /// Mutates the wrapped value in a thread-safe manner.
    ///
    /// - Parameter mutation: A closure that receives an inout reference to the wrapped value for mutation, synchronized for write access.
    func mutate(_ mutation: (inout ValueType) throws -> Void) rethrows {
        return try mutex.withLock { try mutation(&value) }
    }
    
}

// MARK: - Recursive mutex implementation

/// A mutex implementation that uses the low-level `pthread_mutex_t` for thread synchronization.
///
/// `RecursiveMutex` provides a simple way to handle mutual exclusion with recursive locking capabilities.
/// This is useful when a thread needs to acquire the mutex multiple times without causing a deadlock.
/// The mutex is implemented using POSIX threads and is initialized as a recursive mutex to allow reentrant locking.
class RecursiveMutex: NSLocking {
    
    // MARK: - Properties
    
    /// The underlying POSIX mutex used for synchronization.
    /// This mutex is initialized as a recursive mutex to support reentrant locking.
    let mutex: UnsafeMutablePointer<pthread_mutex_t>
    
    // MARK: - Initialization
    
    /// Initializes a new `RecursiveMutex`.
    ///
    /// This constructor sets up the mutex attributes to support recursive locking,
    /// initializes the mutex with these attributes, and then destroys the attribute object.
    init() {
        let mutexAttr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
        pthread_mutexattr_init(mutexAttr)
        pthread_mutexattr_settype(mutexAttr, Int32(PTHREAD_MUTEX_RECURSIVE))
        mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        pthread_mutex_init(mutex, mutexAttr)
        pthread_mutexattr_destroy(mutexAttr)
        mutexAttr.deallocate()
    }
    
    /// Deinitializes and destroys the `RecursiveMutex`.
    ///
    /// This method is called automatically when the instance is deallocated.
    /// It cleans up and releases the resources used by the mutex.
    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deallocate()
    }
    
    // MARK: - Functions
    
    /// Acquires the mutex lock.
    ///
    /// This method locks the mutex, blocking the current thread until the lock is acquired.
    /// It allows reentrant locking by the same thread due to the recursive nature of the mutex.
    @inline(__always) func lock() {
        pthread_mutex_lock(mutex)
    }
    
    /// Releases the mutex lock.
    ///
    /// This method unlocks the mutex, allowing other threads to acquire the lock.
    /// It must be called after acquiring the lock to ensure proper synchronization.
    @inline(__always) func unlock() {
        pthread_mutex_unlock(mutex)
    }
    
}
