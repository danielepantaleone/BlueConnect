//
//  BleCentralManagerProxy+Disconnection.swift
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
    
    /// Disconnects a BLE peripheral and optionally notifies via a callback when the operation completes.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// bleCentralManagerProxy.disconnect(peripheral: peripheral) { result in
    ///     switch result {
    ///         case .success:
    ///             print("Successfully disconnected")
    ///         case .failure(let error):
    ///             print("Failed to disconnect: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to disconnect.
    ///   - callback: A closure called with a `Result<Void, Error>`, providing success or failure of the disconnection attempt.
    ///     If the disconnection is successful, `.success(())` is passed. If the operation fails, `.failure(Error)` is passed with an appropriate error.
    ///
    /// - Note: If the peripheral is already in a `.disconnected` state, the callback is immediately called with success.
    /// - Note: If the peripheral is already in the process of disconnecting (`.disconnecting` state), the method does not reinitiate the disconnection.
    public func disconnect(peripheral: BlePeripheral, callback: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        let subscription = buildSubscription(peripheral: peripheral, callback: callback)
        disconnect(peripheral: peripheral, subscription: subscription)
    }
    
    /// Disconnects from a specified BLE peripheral asynchronously.
    ///
    /// Example usage:
    ///
    /// ```swift
    /// do {
    ///     try await bleCentralManagerProxy.disconnect(peripheral: peripheral)
    /// } catch {
    ///     print("Failed to connect: \(error)")
    /// }
    /// ```
    ///
    /// - Parameter peripheral: The `BlePeripheral` to disconnect.
    ///
    /// - Throws: An error if the disconnection fails.
    public func disconnect(peripheral: BlePeripheral) async throws {
        let box = SubscriptionBox<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildSubscription(peripheral: peripheral, callback: { continuation.resume(with: $0) })
                box.value = subscription
                return disconnect(peripheral: peripheral, subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.value {
                disconnectionRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    // MARK: - Private
    
    /// Internal shared logic to register and wait for peripheral disconnection, abstracting over how the result is delivered.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to disconnect.
    ///   - callback: A closure that receives a `Result` indicating either success or failure.
    ///
    /// - Returns: A `Subscription` to be notified whenever the peripheral is disconnected.
    private func buildSubscription(peripheral: BlePeripheral, callback: @escaping (Result<Void, Error>) -> Void) -> Subscription<Void> {
        disconnectionRegistry.register(key: peripheral.identifier, callback: callback)
    }
    
    /// Disconnects from a specified BLE peripheral asynchronously.
    ///
    /// - Parameters:
    ///   - peripheral: The `BlePeripheral` to disconnect.
    ///   - subscription: The subscription to notify with either success or failure.
    ///
    /// - Throws: An error if the disconnection fails.
    private func disconnect(peripheral: BlePeripheral, subscription: Subscription<Void>) {
            
        var resultToNotify: Result<Void, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                // FIXME: NOTIFY USING REGISTRY
                subscription.notify(result)
            }
        }
        
        // Ensure central manager is in a powered-on state.
        guard centralManager.state == .poweredOn else {
            resultToNotify = .failure(BleCentralManagerProxyError.invalidState(state))
            return
        }
        
        // If already disconnected, notify success (not on publisher since it's already disconnected).
        guard peripheral.state != .disconnected else {
            resultToNotify = .success(())
            return
        }
        
        // If already disconnecting, no need to reinitiate disconnection.
        guard peripheral.state != .disconnecting else {
            return
        }
        
        // If this peripheral is not yet fully connected track connection cancel.
        if peripheral.state == .connecting {
            connectionCanceled.insert(peripheral.identifier)
        }

        // Initiate disconnection.
        centralManager.cancelConnection(peripheral)
        
    }
    
}
