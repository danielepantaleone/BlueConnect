//
//  BlePeripheralManagerProxy+WaitUntilReady.swift
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

import Foundation

extension BlePeripheralManagerProxy {
    
    // MARK: - Public
    
    /// Waits until the peripheral manager is in the `.poweredOn` state, executing the callback upon success or failure.
    ///
    /// This method registers a callback that is invoked when the peripheral manager's state changes to `.poweredOn`, or an error occurs.
    /// The method also verifies that the peripheral manager is authorized and supported.
    /// If the peripheral manager is already `.poweredOn`, the callback is invoked immediately with success.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// blePeripheralManagerProxy.waitUntilReady(timeout: .seconds(10)) { result in
    ///     switch result {
    ///         case .success:
    ///             print("Peripheral manager is ready")
    ///         case .failure(let error):
    ///             print("Peripheral manager is not ready: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - timeout: The maximum time to wait for the peripheral manager to become ready. Default is `.never`.
    ///   - callback: A closure that receives a `Result` indicating success or an error if the peripheral manager is unauthorized or unsupported.
    ///
    /// - Note: If the state is already `.poweredOn`, the callback is called immediately with success.
    public func waitUntilReady(timeout: DispatchTimeInterval = .never, callback: @escaping ((Result<Void, Error>) -> Void)) {
        let subscription = buildSubscription(timeout: timeout, callback: callback)
        waitUntilReady(subscription: subscription)
    }
    
    /// Waits asynchronously until the peripheral manager is in the `.poweredOn` state, or throws an error if the state is unauthorized or unsupported.
    ///
    /// This method uses an async/await pattern to wait for the peripheral manager to become ready. It checks the peripheral manager's state and resumes
    /// with success if it is already `.poweredOn`. Otherwise, it waits until the state changes to `.poweredOn` within the specified timeout.
    /// If the state is unauthorized or unsupported, it throws an error.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// do {
    ///     try await peripheralManagerProxy.waitUntilReady(timeout: .seconds(5))
    ///     // Peripheral manager is ready
    /// } catch {
    ///     // Handle error (e.g., unsupported or unauthorized state)
    /// }
    /// ```
    ///
    /// - Parameter timeout: The maximum duration to wait for the peripheral manager to be ready. The default value is `.never`, indicating no timeout.
    /// - Throws: An error if the it's not possible to wait for the peripheral manager to be ready within the provided timeout.
    public func waitUntilReady(timeout: DispatchTimeInterval = .never) async throws {
        let box = SubscriptionBox<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildSubscription(timeout: timeout) { result in
                    globalQueue.async {
                        continuation.resume(with: result)
                    }
                }
                box.value = subscription
                return waitUntilReady(subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                waitUntilReadyRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    // MARK: - Private
    
    /// Internal shared logic to register and wait for readiness, abstracting over how the result is delivered.
    ///
    /// - Parameters:
    ///   - timeout: The maximum duration to wait for the peripheral manager to become ready. The default is `.never`, meaning no timeout.
    ///   - callback: A closure that receives a `Result` indicating either success or failure.
    ///
    /// - Returns: A `Subscription` to be notified whenever the peripheral manager is ready.
    private func buildSubscription(timeout: DispatchTimeInterval, callback: @escaping (Result<Void, Error>) -> Void) -> Subscription<Void> {
        waitUntilReadyRegistry.register(
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BlePeripheralManagerProxyError.readyTimeout))
            }
        )
    }

    /// Asynchronously waits until the peripheral manager reaches the `.poweredOn` state, or throws an error if the state is `.unauthorized` or `.unsupported`.
    ///
    /// If the peripheral manager is already in the `.poweredOn` state, the subscription is immediately notified with success, otherwise, it waits for the state to transition to `.poweredOn` within the specified timeout.
    /// If the peripheral manager is `.unauthorized` or `.unsupported`, the subscription is notified with a corresponding failure.
    ///
    /// - Parameter subscription: The subscription to notify with either success or failure.
    /// - Throws: An error if the peripheral manager is unauthorized, unsupported, or does not reach the `.poweredOn` state within the timeout period.
    private func waitUntilReady(subscription: Subscription<Void>) {
            
        var resultToNotify: Result<Void, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                waitUntilReadyRegistry.notify(subscription: subscription, value: result)
            }
        }

        switch peripheralManager.state {
            case .poweredOn:
                resultToNotify = .success(())
            case .unauthorized:
                resultToNotify = .failure(BlePeripheralManagerProxyError.invalidState(.unauthorized))
            case .unsupported:
                resultToNotify = .failure(BlePeripheralManagerProxyError.invalidState(.unsupported))
            default:
                subscription.start()
        }
        
    }

}
