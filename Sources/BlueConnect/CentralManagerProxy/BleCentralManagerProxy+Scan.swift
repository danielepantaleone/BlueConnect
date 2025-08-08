//
//  BleCentralManagerProxy+Scan.swift
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

import Combine
#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

extension BleCentralManagerProxy {
    
    // MARK: - Public
    
    /// Scans for BLE peripherals with specified services and options.
    ///
    /// This function initiates a scan for BLE peripherals. If a scan is already in progress, the existing scan is terminated and a new one is started right after.
    /// The scan is stopped automatically after the specified timeout, or it can be stopped manually by calling `stopScan()`.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: An optional array of service UUIDs to filter the scan results. If `nil`, it scans for all available peripherals.
    ///   - options: Optional dictionary of options for customizing the scanning behavior.
    ///   - timeout: The time interval after which the scan should stop automatically. Default is 60 seconds.
    ///
    /// - Returns: A publisher that emits a tuple containing the peripheral, advertisement data and RSSI as peripherals are discovered, and completes or fails on error.
    ///
    /// - Note: If the central manager is not in the `.poweredOn` state, the scan fails, and the publisher sends a `.failure` event with an appropriate error.
    public func scanForPeripherals(
        withServices serviceUUIDs: [CBUUID]? = nil,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .seconds(60)
    ) -> AnyPublisher<(
        peripheral: BlePeripheral,
        advertisementData: BleAdvertisementData,
        RSSI: Int
    ), Error> {
                
        lock.lock()
        defer { lock.unlock() }
        
        // If we are already have a subject it means we are already scanning we should already be receiving updates.
        // In this case we notify the completion of previous scan and we start a new one (killing any previous timer).
        discoverTimer?.cancel()
        discoverTimer = nil
        discoverSubject?.send(completion: .finished)
        discoverSubject = nil
        
        // Create a passthrough subject through which manage the whole peripheral discover process.
        let subject: PassthroughSubject<(
            peripheral: BlePeripheral,
            advertisementData: BleAdvertisementData,
            RSSI: Int
        ), Error> = .init()
        
        // Ensure central manager is in a powered-on state.
        guard centralManager.state == .poweredOn else {
            subject.send(completion: .failure(BleCentralManagerProxyError.invalidState(centralManager.state)))
            return subject.eraseToAnyPublisher()
        }
        
        // Store locally to update when timeout expire or on scan stop.
        discoverSubject = subject
        // Start discover timer.
        startDiscoverTimer(timeout: timeout)
        // Initiate discovery.
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        
        return subject.eraseToAnyPublisher()

    }
    
    /// Scans for BLE peripherals with specified services and options.
    ///
    /// This function initiates a scan for BLE peripherals returning an `AsyncThrowingStream` that can be used to iterate over discovered peripherals.
    /// The scan is stopped automatically after the specified timeout, or it can be stopped manually by calling `stopScan()`.
    /// The scan is stopped gracefully if the container `Task` is canceled.
    /// 
    /// - Parameters:
    ///   - serviceUUIDs: An optional array of service UUIDs to filter the scan results. If `nil`, it scans for all available peripherals.
    ///   - options: Optional dictionary of options for customizing the scanning behavior.
    ///   - timeout: The time interval after which the scan should stop automatically. Default is 60 seconds.
    ///
    /// - Returns: An asynchronous stream yelding scan result which is composed of a tuple containing the peripheral, advertisement data and RSSI.
    ///
    /// - Note: If the central manager is not in the `.poweredOn` state, the scan fails, and the async stream is finished with an appropriate error.
    public func scanForPeripherals(
        withServices serviceUUIDs: [CBUUID]? = nil,
        options: [String: Any]? = nil,
        timeout: DispatchTimeInterval = .seconds(60)
    ) -> AsyncThrowingStream<(
        peripheral: BlePeripheral,
        advertisementData: BleAdvertisementData,
        RSSI: Int
    ), Error> {
        AsyncThrowingStream { continuation in
            final class CancellableBox: @unchecked Sendable {
                var cancellable: AnyCancellable?
                var cancellationMonitor: Task<Void, Never>?
                var isTerminated = false
            }
            let box = CancellableBox()
            // Monitor for outer task cancellation.
            box.cancellationMonitor = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s polling
                }
                guard !box.isTerminated else { return }
                box.isTerminated = true
                // If a value is yielded before the continuation is finished with a throwing error, and the
                // consumer stops before consuming the next value, the error is not always thrown.
                // https://forums.swift.org/t/why-does-asyncthrowingstream-silently-finish-without-error-if-cancelled/72777
                continuation.finish(throwing: CancellationError())
            }
            // Start combine scan.
            box.cancellable = scanForPeripherals(
                withServices: serviceUUIDs,
                options: options,
                timeout: timeout
            )
            .receive(on: globalQueue)
            .sink(
                receiveCompletion: { completion in
                    guard !box.isTerminated else { return }
                    box.isTerminated = true
                    switch completion {
                        case .finished:
                            continuation.finish()
                        case .failure(let error):
                            continuation.finish(throwing: error)
                    }
                },
                receiveValue: { peripheral, advertisementData, RSSI in
                    continuation.yield((peripheral, advertisementData, RSSI))
                }
            )
            // Cleanup on termination (e.g. caller stops consuming stream)
            continuation.onTermination = { @Sendable [weak self] _ in
                box.cancellable?.cancel()
                box.cancellationMonitor?.cancel()
                self?.stopScan()
            }
        }
    }
    
    /// Stops the current BLE peripheral scan.
    ///
    /// Stops the  BLE peripherals discovery and completes the scan's publisher with `.finished`.
    public func stopScan() {
        lock.lock()
        defer { lock.unlock() }
        // Stop scanning for peripherals.
        centralManager.stopScan()
        // Stop discover timer.
        discoverTimer?.cancel()
        discoverTimer = nil
        // Send publisher completion.
        let subject = discoverSubject
        discoverSubject = nil
        subject?.send(completion: .finished)
    }
    
    // MARK: - Private
    
    private func startDiscoverTimer(timeout: DispatchTimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        guard timeout != .never else {
            discoverTimer?.cancel()
            discoverTimer = nil
            return
        }
        discoverTimer?.cancel()
        discoverTimer = DispatchSource.makeTimerSource(queue: globalQueue)
        discoverTimer?.schedule(deadline: .now() + timeout, repeating: .never)
        discoverTimer?.setEventHandler { [weak self] in
            self?.stopScan()
        }
        discoverTimer?.resume()
    }
    
}
