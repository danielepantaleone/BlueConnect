//
//  BleCentralManagerProxy+Connection.swift
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
    
    // MARK: - Public
    
    /// Initiates a connection to a BLE peripheral with optional timeout and callback for result notification.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// bleCentralManagerProxy.connect(peripheral: peripheral, timeout: .seconds(10)) { result in
    ///     switch result {
    ///         case .success:
    ///             print("Successfully connected to peripheral")
    ///         case .failure(let error):
    ///             print("Failed to connect: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to connect to.
    ///   - options: A dictionary of options to customize the connection behavior, such as `CBConnectPeripheralOptionNotifyOnConnectionKey`. Defaults to `nil`.
    ///   - timeout: A `DispatchTimeInterval` specifying how long to wait before considering the connection as failed due to timeout. Defaults to `.never`, meaning no timeout.
    ///   - callback: A closure called with a `Result<Void, Error>` indicating the success or failure of the connection attempt. If the connection is successful, `.success(())` is passed. If it fails, `.failure(Error)` is passed with an appropriate error.
    ///
    /// - Note: If the peripheral is already in a `.connected` state, the callback is immediately invoked with success.
    /// - Note: If the peripheral is already in the process of connecting (`.connecting` state), the method does not reinitiate the connection.
    public func connect(
        peripheral: BlePeripheral,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never,
        callback: @escaping (Result<Void, Error>) -> Void = { _ in }
    ) {
        let subscription = buildSubscription(peripheral: peripheral, timeout: timeout, callback: callback)
        connect(peripheral: peripheral, options: options, subscription: subscription)
    }
    
    /// Connects to a specified BLE peripheral asynchronously.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// do {
    ///     try await bleCentralManagerProxy.connect(peripheral: peripheral, timeout: .seconds(10))
    /// } catch {
    ///     print("Failed to connect: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to connect to.
    ///   - options: A dictionary of options to customize the connection behavior, such as `CBConnectPeripheralOptionNotifyOnConnectionKey`. Defaults to `nil`.
    ///   - timeout: A `DispatchTimeInterval` specifying how long to wait before considering the connection as failed due to timeout. Defaults to `.never`, meaning no timeout.
    ///
    /// - Throws: An error if the connection fails or if the operation times out.
    public func connect(
        peripheral: BlePeripheral,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .never
    ) async throws {
        let box = SubscriptionBox<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildSubscription(peripheral: peripheral, timeout: timeout, callback: { continuation.resume(with: $0) })
                box.value = subscription
                return connect(peripheral: peripheral, options: options, subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                connectionRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    // MARK: - Private
    
    /// Internal shared logic to register and wait for peripheral connection, abstracting over how the result is delivered.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to connect to.
    ///   - timeout: The maximum duration to wait for the central manager to connect the peripheral. The default is `.never`, meaning no timeout.
    ///   - callback: A closure that receives a `Result` indicating either success or failure.
    ///
    /// - Returns: A `Subscription` to be notified whenever the peripheral connects.
    private func buildSubscription(
        peripheral: BlePeripheral,
        timeout: DispatchTimeInterval,
        callback: @escaping (Result<Void, Error>) -> Void
    ) -> Subscription<Void> {
        
        connectionRegistry.register(
            key: peripheral.identifier,
            callback: callback,
            timeout: timeout
        ) { [weak self, weak peripheral] subscription in
            
            guard let self else { return }
            guard let peripheral else { return }
            
            // If the peripheral managed to connect somehow, avoid to disconnect it.
            // We assume the connection was already advertised on the callback and combine publisher.
            guard peripheral.state != .connected else {
                return
            }
            
            // We track the connection timeout for this peripheral to trigger the
            // correct publisher after disconnecting the peripheral from the central.
            lock.lock()
            connectionTimeouts.insert(peripheral.identifier)
            lock.unlock()
            
            // We attempt to disconnect the peripheral prior notifying.
            disconnect(peripheral: peripheral) { _ in
                // Notify only the subscription, the published is triggered by the the delegate.
                // This is because when the timeout handler is executed, the subscription is removed
                // from the registry hence we cannot execute the callback from the delegate.
                subscription.notify(.failure(BleCentralManagerProxyError.connectionTimeout))
            }
            
        }
        
    }
    
    /// Connects to a specified BLE peripheral asynchronously.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to connect to.
    ///   - options: A dictionary of options to customize the connection behavior, such as `CBConnectPeripheralOptionNotifyOnConnectionKey`. Defaults to `nil`.
    ///   - subscription: The subscription to notify with either success or failure.
    private func connect(
        peripheral: BlePeripheral,
        options: [String: Any]? = nil,
        subscription: Subscription<Void>
    ) {
            
        var resultToNotify: Result<Void, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                connectionRegistry.notify(subscription: subscription, value: result)
            }
        }
        
        // Ensure central manager is in a powered-on state.
        guard centralManager.state == .poweredOn else {
            resultToNotify = .failure(BleCentralManagerProxyError.invalidState(state))
            return
        }
        
        // If already connected, notify success (not on publisher since it's not a new connection).
        guard peripheral.state != .connected else {
            resultToNotify = .success(())
            return
        }
        
        // Track connection state.
        connectionState[peripheral.identifier] = .connecting
        // Remove any connection cancel tracking for this peripheral.
        connectionCanceled.remove(peripheral.identifier)

        // If already connecting, no need to reinitiate connection
        guard peripheral.state != .connecting else {
            return
        }
        
        // Begin monitoring connection timeout.
        subscription.start()

        // Initiate connection.
        centralManager.connect(peripheral, options: options)
        
    }
    
}
