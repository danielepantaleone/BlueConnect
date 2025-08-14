//
//  BlePeripheralProxy.swift
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

import Combine
#if swift(>=6.0)
@preconcurrency import CoreBluetooth
#else
import CoreBluetooth
#endif
import Foundation

/// `BlePeripheralProxy` provides an interface for interacting with a BLE peripheral and managing BLE operations.
///
/// This class uses Combine publishers to emit updates on BLE-related events, such as service discovery, characteristic updates, and RSSI changes.
/// It also manages caching of BLE characteristics and handles asynchronous BLE operations like read, write, and notifications.
public final class BlePeripheralProxy: NSObject, @unchecked Sendable {
    
    // MARK: - Public properties
    
    /// The `BlePeripheral` instance this proxy manages.
    public let peripheral: BlePeripheral
    
    // MARK: - Publishers
    
    /// A publisher that emits when characteristics are discovered for a service.
    /// It emits a tuple containing the service and an array of characteristics.
    public var didDiscoverCharacteristicsPublisher: AnyPublisher<(service: CBService, characteristics: [CBCharacteristic]), Never> {
        didDiscoverCharacteristicsSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when services are discovered on the peripheral.
    /// It emits an array of discovered services.
    public var didDiscoverServicesPublisher: AnyPublisher<[CBService], Never> {
        didDiscoverServicesSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when the peripheral updates its name.
    /// It emits the updated name of the peripheral as a `String?`.
    public var didUpdateNamePublisher: AnyPublisher<String?, Never> {
        didUpdateNameSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when the notification state for a characteristic changes.
    /// It emits a tuple containing the characteristic and a `Bool` indicating whether notifications are enabled.
    public var didUpdateNotificationStatePublisher: AnyPublisher<(characteristic: CBCharacteristic, enabled: Bool), Never> {
        didUpdateNotificationStateSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits the updated RSSI (Received Signal Strength Indicator) value for the peripheral.
    /// It emits an `Int` representing the RSSI.
    public var didUpdateRSSIPublisher: AnyPublisher<Int, Never> {
        didUpdateRSSISubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when a characteristic's value has been updated.
    /// It emits a tuple containing the characteristic and the updated value as `Data`.
    public var didUpdateValuePublisher: AnyPublisher<(characteristic: CBCharacteristic, data: Data), Never> {
        didUpdateValueSubject.eraseToAnyPublisher()
    }
    
    /// A publisher that emits when a characteristic write operation completes.
    /// It emits the characteristic that was written.
    public var didWriteValuePublisher: AnyPublisher<CBCharacteristic, Never> {
        didWriteValueSubject.eraseToAnyPublisher()
    }
   
    // MARK: - Internal properties
    
    var cache: [CBUUID: BlePeripheralCacheRecord] = [:]
    var readingCharacteristics: Set<CBUUID> = []
    var rssiTimer: DispatchSourceTimer?
    let lock = NSRecursiveLock()
    
    let characteristicReadRegistry: KeyedRegistry<CBUUID, Data> = .init()
    let characteristicNotifyRegistry: KeyedRegistry<CBUUID, Bool> = .init()
    let characteristicWriteRegistry: KeyedRegistry<CBUUID, Void> = .init()
    let discoverCharacteristicRegistry: KeyedRegistry<CBUUID, CBCharacteristic> = .init()
    let discoverServiceRegistry: KeyedRegistry<CBUUID, CBService> = .init()
    let rssiReadRegistry: ListRegistry<Int> = .init()

    let didDiscoverCharacteristicsSubject: PassthroughSubject<(service: CBService, characteristics: [CBCharacteristic]), Never> = .init()
    let didDiscoverServicesSubject: PassthroughSubject<[CBService], Never> = .init()
    let didUpdateNameSubject: PassthroughSubject<String?, Never> = .init()
    let didUpdateNotificationStateSubject: PassthroughSubject<(characteristic: CBCharacteristic, enabled: Bool), Never> = .init()
    let didUpdateRSSISubject: PassthroughSubject<Int, Never> = .init()
    let didUpdateValueSubject: PassthroughSubject<(characteristic: CBCharacteristic, data: Data), Never> = .init()
    let didWriteValueSubject: PassthroughSubject<CBCharacteristic, Never> = .init()
    
    // MARK: - Initialization
    
    /// Unavailable initializer.
    /// Use `init(peripheral:)` instead.
    @available(*, unavailable, message: "Use init(peripheral:) instead.")
    public override init() {
        fatalError("use init(peripheral:)")
    }
    
    /// Initializes a new `BlePeripheralProxy` with the provided peripheral.
    ///
    /// - Parameter peripheral: The `BlePeripheral` instance to interact with.
    public init(peripheral: BlePeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral.peripheralDelegate = self
    }
    
    /// Perform `BlePeripheralProxy` graceful deinitialization.
    deinit {
        
        lock.lock()
        defer { lock.unlock() }
        
        peripheral.peripheralDelegate = nil
        readingCharacteristics.removeAll()
        cache.removeAll()
        rssiTimer?.cancel()
        rssiTimer = nil
        
        // Notify registries about shutdown.
        characteristicReadRegistry.notifyAll(.failure(BlePeripheralProxyError.destroyed))
        characteristicNotifyRegistry.notifyAll(.failure(BlePeripheralProxyError.destroyed))
        characteristicWriteRegistry.notifyAll(.failure(BlePeripheralProxyError.destroyed))
        discoverServiceRegistry.notifyAll(.failure(BlePeripheralProxyError.destroyed))
        discoverCharacteristicRegistry.notifyAll(.failure(BlePeripheralProxyError.destroyed))
        rssiReadRegistry.notifyAll(.failure(BlePeripheralProxyError.destroyed))
    
        // Notify publishers.
        didDiscoverCharacteristicsSubject.send(completion: .finished)
        didDiscoverServicesSubject.send(completion: .finished)
        didUpdateNameSubject.send(completion: .finished)
        didUpdateNotificationStateSubject.send(completion: .finished)
        didUpdateRSSISubject.send(completion: .finished)
        didUpdateValueSubject.send(completion: .finished)
        didWriteValueSubject.send(completion: .finished)
        
    }
    
}
