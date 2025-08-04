//
//  BleCentralManagerProxy+WaitUntilReady.swift
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

extension BleCentralManagerProxy {
    
    /// Waits until the central manager reaches the `.poweredOn` state, executing the callback upon success or failure.
    ///
    /// This method registers a callback that is invoked when the central manager becomes ready (i.e., transitions to the `.poweredOn` state),
    /// or when an error occurs due to an unsupported or unauthorized state, or a timeout.
    /// If the central manager is already `.poweredOn`, the callback is invoked immediately with success.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// bleCentralManagerProxy.waitUntilReady(timeout: .seconds(10)) { result in
    ///     switch result {
    ///     case .success:
    ///         print("Central manager is ready")
    ///     case .failure(let error):
    ///         print("Central manager is not ready: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - timeout: The maximum duration to wait for the central manager to become ready. The default is `.never`, meaning no timeout.
    ///   - callback: A closure that receives a `Result` indicating either success, or failure if the central manager is unauthorized, unsupported, or if the timeout is exceeded.
    public func waitUntilReady(timeout: DispatchTimeInterval = .never, callback: @escaping ((Result<Void, Error>) -> Void)) {
        let subscription = waitUntilReadyRegistry.register(
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BleCentralManagerProxyError.readyTimeout))
            }
        )
        waitUntilReady(subscription: subscription)
    }
    
    /// Waits asynchronously until the central manager reaches the `.poweredOn` state, or throws an error if the state is `.unauthorized` or `.unsupported`.
    ///
    /// This method uses the async/await pattern to wait for the central manager to become ready.
    /// If the central manager is already in the `.poweredOn` state, the method resumes immediately with success.
    /// Otherwise, it waits for the state to transition to `.poweredOn` within the specified timeout period.
    /// If the state is `.unauthorized` or `.unsupported`, the method throws an appropriate error.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// do {
    ///     try await centralManagerProxy.waitUntilReady(timeout: .seconds(5))
    ///     // Central manager is ready
    /// } catch {
    ///     // Handle error (e.g., unsupported/unauthorized state, or timeout)
    /// }
    /// ```
    ///
    /// - Parameter timeout: The maximum duration to wait for the central manager to become ready. The default is `.never`, meaning no timeout.
    /// - Throws: An error if the central manager fails to reach the `.poweredOn` state within the timeout, or if it is unauthorized or unsupported.
    public func waitUntilReady(timeout: DispatchTimeInterval = .never) async throws {
        let box = SubscriptionBox<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = waitUntilReadyRegistry.register(
                    callback: { continuation.resume(with: $0) },
                    timeout: timeout,
                    timeoutHandler: { subscription in
                        subscription.notify(.failure(BleCentralManagerProxyError.readyTimeout))
                    }
                )
                box.value = subscription
                return waitUntilReady(subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                waitUntilReadyRegistry.notify(
                    subscription: subscription,
                    value: .failure(CancellationError())
                )
            }
        }
    }
    
    /// Asynchronously waits until the central manager reaches the `.poweredOn` state, or throws an error if the state is `.unauthorized` or `.unsupported`.
    ///
    /// This method follows the async/await pattern to wait for the central manager to become ready.
    /// If the central manager is already in the `.poweredOn` state, the subscription is immediately notified with success.
    /// Otherwise, it waits for the state to transition to `.poweredOn` within the specified timeout.
    /// If the central manager is `.unauthorized` or `.unsupported`, the subscription is notified with a corresponding failure.
    ///
    /// - Parameter subscription: The subscription to notify with either success or failure.
    /// - Throws: An error if the central manager is unauthorized, unsupported, or does not reach the `.poweredOn` state within the timeout period.
    func waitUntilReady(subscription: Subscription<Void>) {
            
        var resultToNotify: Result<Void, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                subscription.notify(result)
            }
        }

        switch centralManager.state {
            case .poweredOn:
                resultToNotify = .success(())
            case .unauthorized:
                resultToNotify = .failure(BleCentralManagerProxyError.invalidState(.unauthorized))
            case .unsupported:
                resultToNotify = .failure(BleCentralManagerProxyError.invalidState(.unsupported))
            default:
                subscription.start()
        }
        
    }
    
}
