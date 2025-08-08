//
//  BlePeripheralManagerProxy+Advertising.swift
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

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

extension BlePeripheralManagerProxy {
    
    // MARK: - Public
    
    /// Starts advertising peripheral data.
    ///
    /// Initiates advertising of the peripheral's services and other provided advertisement data.
    /// The method ensures that the peripheral manager is in a powered-on state before starting the advertising process.
    /// A callback is invoked with the result of the operation, either success or an error.
    ///
    /// - Parameters:
    ///   - advertisementData: A dictionary containing data to advertise, such as service UUIDs and the local name. Defaults to `nil` if no advertisement data is provided.
    ///   - timeout: The time interval to wait for the advertising to start before timing out. Defaults to `.never`, meaning no timeout is applied.
    ///   - callback: A closure that is called with the result of the advertising operation. The closure is passed a `Result` type, which is `.success` on successful advertising start or `.failure` with an error if the operation fails. Defaults to a no-op closure.
    public func startAdvertising(
        _ advertisementData: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never,
        callback: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        let subscription = buildAdvStartSubscription(timeout: timeout, callback: callback)
        startAdvertising(advertisementData: advertisementData, subscription: subscription)
    }
    
    /// Starts advertising peripheral data.
    ///
    /// Initiates advertising of the peripheral's services and other provided advertisement data.
    ///
    /// - Parameters:
    ///   - advertisementData: A dictionary containing data to advertise, such as service UUIDs and the local name. Defaults to `nil` if no advertisement data is provided.
    ///   - timeout: The time interval to wait for the advertising operation to complete before timing out. Defaults to `.never`, meaning no timeout is applied.
    ///
    /// - Throws: An error if the advertising start operation fails or times out.
    public func startAdvertising(
        _ advertisementData: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never
    ) async throws {
        let box = SubscriptionBox<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildAdvStartSubscription(timeout: timeout) { result in
                    globalQueue.async {
                        continuation.resume(with: result)
                    }
                }
                box.value = subscription
                return startAdvertising(advertisementData: advertisementData, subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                startAdvertisingRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    /// Stops advertising peripheral data.
    ///
    /// Calling this method halts any active advertising by the peripheral manager, stopping the broadcast of services and advertisement data.
    ///
    /// - Parameters:
    ///   - timeout: The time interval to wait for the advertising to stop before timing out. Defaults to `.never`, meaning no timeout is applied.
    ///   - callback: A closure that is called with the result of the stop advertising operation. The closure is passed a `Result` type, which is `.success` on successful advertising stop or `.failure` with an error if the operation fails. Defaults to a no-op closure.
    public func stopAdvertising(
        timeout: DispatchTimeInterval = .never,
        callback: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        let subscription = buildAdvStopSubscription(timeout: timeout, callback: callback)
        stopAdvertising(subscription: subscription)
    }
    
    /// Stops advertising peripheral data.
    ///
    /// Calling this method halts any active advertising by the peripheral manager, stopping the broadcast of services and advertisement data.
    ///
    /// - Parameters timeout: The time interval to wait for the advertising to stop before timing out. Defaults to `.never`, meaning no timeout is applied.
    /// - Throws: An error if the advertising stop operation fails or times out.
    public func stopAdvertising(timeout: DispatchTimeInterval = .never) async throws {
        let box = SubscriptionBox<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildAdvStopSubscription(timeout: timeout) { result in
                    globalQueue.async {
                        continuation.resume(with: result)
                    }
                }
                box.value = subscription
                return stopAdvertising(subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                stopAdvertisingRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    // MARK: - Private
    
    /// Internal shared logic to register and wait for advertising start, abstracting over how the result is delivered.
    ///
    /// - Parameters:
    ///   - timeout: The maximum duration to wait for the peripheral manager to start advertising. The default is `.never`, meaning no timeout.
    ///   - callback: A closure that receives a `Result` indicating either success or failure.
    ///
    /// - Returns: A `Subscription` to be notified whenever the peripheral manager starts advertising.
    private func buildAdvStartSubscription(timeout: DispatchTimeInterval, callback: @escaping (Result<Void, Error>) -> Void) -> Subscription<Void> {
        startAdvertisingRegistry.register(
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BlePeripheralManagerProxyError.advertisingTimeout))
            }
        )
    }
    
    /// Internal shared logic to register and wait for advertising stop, abstracting over how the result is delivered.
    ///
    /// - Parameters:
    ///   - timeout: The maximum duration to wait for the peripheral manager to stop advertising. The default is `.never`, meaning no timeout.
    ///   - callback: A closure that receives a `Result` indicating either success or failure.
    ///
    /// - Returns: A `Subscription` to be notified whenever the peripheral manager stops advertising.
    private func buildAdvStopSubscription(timeout: DispatchTimeInterval, callback: @escaping (Result<Void, Error>) -> Void) -> Subscription<Void> {
        stopAdvertisingRegistry.register(
            callback: callback,
            timeout: timeout,
            timeoutHandler: { subscription in
                subscription.notify(.failure(BlePeripheralManagerProxyError.advertisingTimeout))
            }
        )
    }
    
    /// Starts advertising peripheral data.
    ///
    /// Initiates advertising of the peripheral's services and other provided advertisement data.
    ///
    /// - Parameters:
    ///   - advertisementData: A dictionary containing data to advertise, such as service UUIDs and the local name. Defaults to `nil` if no advertisement data is provided.
    ///   - subscription: The subscription to notify with either success or failure.
    private func startAdvertising(advertisementData: [String: Any]? = nil, subscription: Subscription<Void>) {
            
        var resultToNotify: Result<Void, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                startAdvertisingRegistry.notify(subscription: subscription, value: result)
            }
        }
        
        // Ensure peripheral manager is in a powered-on state.
        guard peripheralManager.state == .poweredOn else {
            resultToNotify = .failure(BlePeripheralManagerProxyError.invalidState(peripheralManager.state))
            return
        }

        // Exit early if already advertising.
        guard !isAdvertising else {
            resultToNotify = .success(())
            return
        }

        // Begin monitoring timeout.
        subscription.start()

        // Try to start advertising.
        peripheralManager.startAdvertising(advertisementData)
        
    }
    
    /// Stops advertising peripheral data.
    ///
    /// Calling this method halts any active advertising by the peripheral manager, stopping the broadcast of services and advertisement data.
    ///
    /// - Parameter subscription: The subscription to notify with either success or failure.
    private func stopAdvertising(subscription: Subscription<Void>) {
       
        var resultToNotify: Result<Void, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                stopAdvertisingRegistry.notify(subscription: subscription, value: result)
            }
        }
        
        // Ensure peripheral manager is in a powered-on state.
        guard peripheralManager.state == .poweredOn else {
            resultToNotify = .failure(BlePeripheralManagerProxyError.invalidState(peripheralManager.state))
            return
        }

        // Exit early if not advertising.
        guard isAdvertising else {
            resultToNotify = .success(())
            return
        }
        
        // If we do not have an advertising monitor running (very unlikely) we have to provide early feedback.
        guard advertisingMonitor != nil && !advertisingMonitor!.isCancelled else {
            peripheralManager.stopAdvertising()
            resultToNotify = .success(())
            return
        }

        // Begin monitoring timeout.
        subscription.start()

        // Try to stop advertising.
        peripheralManager.stopAdvertising()
        
    }
    
}
