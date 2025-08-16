//
//  BlePeripheralProxy+RSSI.swift
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

#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

extension BlePeripheralProxy {
    
    // MARK: - Public
    
    /// Indicates whether RSSI notifications are currently active for the connected peripheral.
    ///
    /// - Returns: A Boolean value: `true` if RSSI notifications are enabled; otherwise, `false`.
    public var isRSSINotifying: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard peripheral.state == .connected else { return false }
        guard let rssiTimer else { return false }
        guard !rssiTimer.isCancelled else { return false }
        return true
    }
    
    /// Reads the RSSI (Received Signal Strength Indicator) value of the peripheral.
    ///
    /// This method attempts to read the RSSI value of the connected peripheral within a specified timeout period.
    ///
    /// - Parameters:
    ///   - timeout: The maximum time to wait for an RSSI read operation. Defaults to 10 seconds.
    ///   - callback: A closure that is called with the result of the RSSI read operation. The closure is passed a `Result` containing the RSSI value or an error if the read fails.
    public func readRSSI(timeout: DispatchTimeInterval = .seconds(10), callback: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        let subscription = buildSubscription(timeout: timeout, callback: callback)
        readRSSI(subscription: subscription)
    }
    
    /// Reads the RSSI (Received Signal Strength Indicator) value of the peripheral.
    ///
    /// This method attempts to read the RSSI value of the connected peripheral within a specified timeout period.
    ///
    /// - Parameter timeout: The maximum time to wait for an RSSI read operation. Defaults to 10 seconds.
    /// - Returns: The RSSI value representing the signal strength in dBm.
    /// - Throws: An error if the peripheral RSSI value cannot be read within the specified timeout or is not valid.
    public func readRSSI(timeout: DispatchTimeInterval = .seconds(10)) async throws -> Int {
        let box = SubscriptionBox<Int>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let subscription = buildSubscription(timeout: timeout) { result in
                    globalQueue.async {
                        continuation.resume(with: result)
                    }
                }
                box.subscription = subscription
                readRSSI(subscription: subscription)
            }
        } onCancel: {
            if let subscription = box.subscription {
                rssiReadRegistry.notify(subscription: subscription, value: .failure(CancellationError()))
            }
        }
    }
    
    /// Enables or disables RSSI signal strength notifications.
    ///
    /// When enabled, the peripheral periodically reads its RSSI (Received Signal Strength Indicator),
    /// and the values are emitted through a Combine publisher at the specified interval.
    ///
    /// - Parameters:
    ///   - enabled: Set to `true` to enable RSSI notifications, or `false` to disable them.
    ///   - rate: The interval at which RSSI updates are emitted. Ignored when disabling notifications.
    ///
    /// - Throws: `BlePeripheralProxyError.peripheralNotConnected` if the peripheral is not currently connected.
    ///
    /// - Note: If the requested state is already active, no action is taken.
    public func setRSSINotify(enabled: Bool, rate: DispatchTimeInterval = .seconds(1)) throws {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            throw BlePeripheralProxyError.peripheralNotConnected
        }
        
        if enabled && rssiTimer == nil {
            rssiTimer?.cancel()
            rssiTimer = DispatchSource.makeTimerSource(queue: globalQueue)
            rssiTimer?.schedule(deadline: .now() + rate, repeating: rate)
            rssiTimer?.setEventHandler { [weak self] in
                guard let self else { return }
                lock.lock()
                defer { lock.unlock() }
                guard peripheral.state == .connected else {
                    rssiTimer?.cancel()
                    rssiTimer = nil
                    return
                }
                peripheral.readRSSI()
            }
            rssiTimer?.resume()
        } else if !enabled && rssiTimer != nil  {
            rssiTimer?.cancel()
            rssiTimer = nil
        }
        
    }
    
    // MARK: - Private
        
    private func buildSubscription(timeout: DispatchTimeInterval, callback: @escaping (Result<Int, Error>) -> Void) -> Subscription<Int> {
        rssiReadRegistry.register(
            callback: callback,
            timeout: timeout,
            timeoutHandler: { [weak self] subscription in
                self?.rssiReadRegistry.notify(subscription: subscription, value: .failure(BlePeripheralProxyError.rssiReadTimeout))
            }
        )
    }
    
    private func readRSSI(subscription: Subscription<Int>) {
        
        var resultToNotify: Result<Int, Error>? = nil
        
        lock.lock()
        defer {
            lock.unlock()
            if let result = resultToNotify {
                rssiReadRegistry.notify(subscription: subscription, value: result)
            }
        }
        
        guard peripheral.state == .connected else {
            resultToNotify = .failure(BlePeripheralProxyError.peripheralNotConnected)
            return
        }
        
        // Begin monitoring RSSI read timeout.
        subscription.start()

        // Read RSSI.
        peripheral.readRSSI()

    }
    
}
