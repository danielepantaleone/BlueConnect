//
//  Registry.swift
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

/// A globack lock to manage registry thread safety.
nonisolated(unsafe) let registryLock = RecursiveMutex()

// MARK: - Subscription

/// A `Subscription` that manages an asynchronous callback with a timeout.
///
/// Subscriptions are notified when a result becomes available, an error occurs, or when the timeout is reached if no notification has occurred.
///
/// - Note: This class conforms to `Identifiable` and `Equatable`.
class Subscription<ValueType>: Identifiable, Equatable {
    
    /// The state of the subscription.
    enum State {
        /// Subscription was just created.
        case created
        /// Subscription has a timer running but has not yet been notified.
        case started
        /// Subscription was notified and completed its purpose.
        case notified
    }
    
    // MARK: - Properties
    
    /// A unique identifier for the subscription instance.
    let id = UUID()
    /// The callback function that is invoked when the subscription is notified.
    let callback: (Result<ValueType, Error>) -> Void
    /// The duration of time after which the subscription times out.
    let timeout: DispatchTimeInterval
    /// The function called when the subscription times out.
    let timeoutHandler: (Subscription) -> Void
   
    /// A timer that triggers the timeout handler when the subscription times out.
    private var timer: DispatchSourceTimer?
    /// The current state of the subscription.
    private var state: State = .created
    
    // MARK: - Initialization
    
    /// Creates a new `Subscription` instance with the specified callback, timeout, and timeout handler.
    ///
    /// - Parameters:
    ///   - callback: A closure to be called when the subscription is notified with a result.
    ///   - timeout: The time duration after which the subscription times out.
    ///   - timeoutHandler: A closure to be called when the subscription times out.
    init(
        callback: @escaping (Result<ValueType, Error>) -> Void,
        timeout: DispatchTimeInterval,
        timeoutHandler: @escaping (Subscription) -> Void
    ) {
        self.callback = callback
        self.timeout = timeout
        self.timeoutHandler = timeoutHandler
    }
    
    // MARK: - Functions
    
    /// Notifies the subscription with the specified result, triggering the callback and cancelling the timer.
    ///
    /// - Parameter value: The result to notify the subscription with.
    func notify(_ value: Result<ValueType, Error>) {
        registryLock.lock()
        guard state != .notified else {
            registryLock.unlock()
            return
        }
        state = .notified
        timer?.cancel()
        timer = nil
        registryLock.unlock()
        callback(value)
    }
    
    /// Starts the subscription's timer if it has a timeout and changes its state to `started`.
    ///
    /// - Note: If `timeout` is `.never`, the subscription is not started.
    func start() {
        registryLock.lock()
        defer { registryLock.unlock() }
        guard state == .created else { return }
        guard timeout != .never else { return }
        state = .started
        timer = DispatchSource.makeTimerSource()
        timer?.schedule(deadline: .now() + timeout, repeating: .never)
        timer?.setEventHandler { [weak self] in
            guard let self else { return }
            registryLock.lock()
            timer?.cancel()
            timer = nil
            registryLock.unlock()
            timeoutHandler(self)
        }
        timer?.resume()
    }
    
    // MARK: - Equatable conformance
    
    static func == (lhs: Subscription<ValueType>, rhs: Subscription<ValueType>) -> Bool {
        return lhs.id == rhs.id
    }
    
}

// MARK: - KeyedRegistry

/// A registry that manages subscriptions associated with specific keys.
///
/// `KeyedRegistry` stores and manages subscriptions, allowing notifications to be sent to all subscriptions
/// or specific ones associated with a given key. Each subscription has a callback and a timeout handler
/// to be invoked if it is not notified within the specified timeout.
///
/// - Note: `KeyType` must conform to `Hashable`.
class KeyedRegistry<KeyType, ValueType> where KeyType: Hashable {
    
    // MARK: - Properties
    
    /// A dictionary that stores subscriptions grouped by a unique key.
    private var subscriptions: [KeyType: [Subscription<ValueType>]] = [:]
    
    // MARK: - Interface
    
    /// Notifies all subscriptions in the registry with the given result and removes them from the registry.
    ///
    /// - Parameter value: The result to pass to each subscription's callback.
    func notifyAll(_ value: Result<ValueType, Error>) {
        registryLock.lock()
        let locals = subscriptions.values.flatMap { $0 }
        subscriptions.removeAll()
        registryLock.unlock()
        for subscription in locals {
            subscription.notify(value)
        }
    }
    
    /// Notifies all subscriptions associated with a specific key and removes them from the registry.
    ///
    /// - Parameters:
    ///   - key: The key whose subscriptions should be notified.
    ///   - value: The result to pass to the callback of each subscription associated with the key.
    func notify(key: KeyType, value: Result<ValueType, Error>) {
        registryLock.lock()
        let locals = subscriptions[key].emptyIfNil
        subscriptions[key] = []
        registryLock.unlock()
        for subscription in locals {
            subscription.notify(value)
        }
    }
    
    /// Retrieves all subscriptions associated with the specified key.
    ///
    /// - Parameter key: The key for which to retrieve subscriptions.
    /// - Returns: An array of subscriptions associated with the specified key. If no subscriptions are found, an empty array is returned.
    func subscriptions(with key: KeyType) -> [Subscription<ValueType>] {
        registryLock.lock()
        defer { registryLock.unlock() }
        return subscriptions[key].emptyIfNil
    }
    
    /// Registers a new subscription with the specified key, callback, timeout, and timeout handler.
    ///
    /// - Parameters:
    ///   - key: The key with which to associate the subscription.
    ///   - callback: A closure to be invoked when the subscription is notified with a result.
    ///   - timeout: The duration after which the subscription times out if not notified, defaults to `.never`.
    ///   - timeoutHandler: A closure to be called when the subscription times out, defaults to empty closure.
    ///
    /// - Note: The subscription is started immediately, which begins tracking its timeout if one is set.
    func register(
        key: KeyType,
        callback: @escaping ((Result<ValueType, Error>) -> Void),
        timeout: DispatchTimeInterval = .never,
        timeoutHandler: @escaping (Subscription<ValueType>) -> Void = { _ in }
    ) {
        
        registryLock.lock()
        defer { registryLock.unlock() }
        
        // Create and store the subscription in the registry.
        let subscription = Subscription(
            callback: callback,
            timeout: timeout
        ) { [weak self] subscription in
            guard let self else { return }
            registryLock.lock()
            subscriptions[key] = subscriptions[key]?.filter { $0 != subscription }
            registryLock.unlock()
            timeoutHandler(subscription)
        }
        if subscriptions[key] == nil {
            subscriptions[key] = []
        }
        subscriptions[key]?.append(subscription)
        
        // Start tracking the subscription's timeout (if any).
        subscription.start()
        
    }
    
}
