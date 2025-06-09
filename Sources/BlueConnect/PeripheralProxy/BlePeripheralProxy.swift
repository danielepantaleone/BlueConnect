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
@preconcurrency import CoreBluetooth
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
    
    // MARK: - Internals
    
    /// Retrieves a service by its UUID from the peripheral's list of services.
    ///
    /// - Parameter uuid: The UUID of the service to retrieve.
    /// - Returns: The `CBService` if found, otherwise `nil`.
    func getService(_ uuid: CBUUID) -> CBService? {
        lock.lock()
        defer { lock.unlock() }
        return peripheral.services?.first(where: { $0.uuid == uuid })
    }
    
    /// Retrieves a characteristic by its UUID from the peripheral's services.
    ///
    /// - Parameter uuid: The UUID of the characteristic to retrieve.
    /// - Returns: The `CBCharacteristic` if found, otherwise `nil`.
    func getCharacteristic(_ uuid: CBUUID) -> CBCharacteristic? {
        lock.lock()
        defer { lock.unlock() }
        for service in peripheral.services.emptyIfNil {
            guard let characteristic = service.characteristics?.first(where: { $0.uuid == uuid }) else {
                continue
            }
            return characteristic
        }
        return nil
    }
    
    /// Retrieves a characteristic by its UUID from the peripheral's service matching the provided service UUID.
    ///
    /// - Parameters:
    ///   - uuid: The UUID of the characteristic to retrieve.
    ///   - serviceUUID: The UUID of the service where to search the characteristic.
    /// - Returns: The `CBCharacteristic` if found, otherwise `nil`.
    func getCharacteristic(_ uuid: CBUUID, serviceUUID: CBUUID) -> CBCharacteristic? {
        lock.lock()
        defer { lock.unlock() }
        guard let service = getService(serviceUUID) else {
            return nil
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == uuid }) else {
            return nil
        }
        return characteristic
    }
    
}

// MARK: - Discovery of services

extension BlePeripheralProxy {
    
    /// Initiates the discovery of a specific service by its UUID and registers a callback to be executed when the service is discovered.
    ///
    /// The discovered service will also trigger the `didDiscoverServicesPublisher`.
    ///
    /// - Parameters:
    ///   - serviceUUID: The UUID of the service to discover.
    ///   - timeout: The timeout for the service discovery operation. Defaults to 10 seconds.
    ///   - callback: A closure to execute when the service is discovered. The closure provides a `Result` containing either the discovered `CBService` or an `Error`.
    public func discover(
        serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<CBService, Error>) -> Void
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        
        if let service = getService(serviceUUID) {
            callback(.success(service))
            return
        }
        
        discoverServiceRegistry.register(
            key: serviceUUID,
            callback: callback,
            timeout: timeout
        ) {
            $0.notify(.failure(BlePeripheralProxyError.serviceNotFound(serviceUUID: serviceUUID)))
        }
        
        peripheral.discoverServices([serviceUUID])
                
    }
    
    /// Initiates the discovery of a set of services, or discovers all available services if `nil` is specified as `serviceUUIDs`.
    ///
    /// The discovered services will trigger the `didDiscoverServicesPublisher` multiple times as services are discovered.
    ///
    /// - Parameter serviceUUIDs: The UUIDs of the services to discover, or `nil` to discover all services on the peripheral.
    public func discover(serviceUUIDs: [CBUUID]?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            return
        }
        
        // Will eventually rediscover already discovered services and notify on the publisher.
        peripheral.discoverServices(serviceUUIDs)
        
    }
    
}

// MARK: - Discovery of characteristics

extension BlePeripheralProxy {
    
    /// Discover a specific characteristic for the provided service and register a callback to be executed when the characteristic is discovered.
    /// The discovered characteristic will also be notified via the `didDiscoverCharacteristicsPublisher`.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic to discover.
    ///   - serviceUUID: The UUID of the service containing the characteristic.
    ///   - timeout: The timeout duration for the characteristic discovery operation. Defaults to 10 seconds.
    ///   - callback: A closure to execute when the characteristic is discovered. The closure provides a `Result` containing either the discovered `CBCharacteristic` or an `Error`.
    public func discover(
        characteristicUUID: CBUUID,
        in serviceUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<CBCharacteristic, Error>) -> Void
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        
        guard let service = getService(serviceUUID) else {
            callback(.failure(BlePeripheralProxyError.serviceNotFound(serviceUUID: serviceUUID)))
            return
        }
        
        if let characteristic = getCharacteristic(characteristicUUID, serviceUUID: serviceUUID) {
            callback(.success(characteristic))
            return
        }
        
        discoverCharacteristicRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout
        ) {
            $0.notify(.failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
        }
        
        peripheral.discoverCharacteristics([characteristicUUID], for: service)
      
    }
    
    /// Discover a set of characteristics for the provided service, or all available characteristics if `nil` is specified for `characteristicUUIDs`.
    /// The discovered characteristics will trigger notifications via the `didDiscoverCharacteristicsPublisher`, which can be triggered multiple times.
    /// If specific characteristics are not found, they will not be advertised, so using `discover(characteristicUUID:in:timeout:callback)` is recommended for specific use cases.
    ///
    /// - Parameters:
    ///   - characteristicUUIDs: An array of UUIDs representing the characteristics to discover, or `nil` to discover all characteristics for the service.
    ///   - serviceUUID: The UUID of the service containing the characteristics.
    public func discover(characteristicUUIDs: [CBUUID]?, in serviceUUID: CBUUID) {
  
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            return
        }

        guard let service = getService(serviceUUID) else {
            return
        }
        
        // Will eventually rediscover already discovered characteristics and notify on the publisher.
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        
    }
    
}

// MARK: - Characteristic read

extension BlePeripheralProxy {
    
    /// Reads the value of a characteristic and notifies the result through the provided callback.
    ///
    /// This method attempts to read the characteristic's value, either from the peripheral or the cache, depending on the specified cache policy.
    /// If a read operation for the same characteristic is already in progress, the operation will not be triggered again.
    ///
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic to read.
    ///   - cachePolicy: The cache policy that dictates whether the value should be fetched from the peripheral or retrieved from the cache. Defaults to `.never`, meaning fresh data is read directly from the peripheral unless specified otherwise.
    ///   - timeout: The timeout for the characteristic read operation. This is ignored if the value is fetched from the cache. Defaults to 10 seconds.
    ///   - callback: A closure that is executed when the read operation completes. The closure is passed a `Result` containing the characteristic's data or an error if the read fails.
    ///
    /// - Note: The read operation will only occur if no other read for the same characteristic is already in progress. Multiple simultaneous read requests for the same characteristic will not trigger multiple read operations.
    public func read(
        characteristicUUID: CBUUID,
        cachePolicy: BlePeripheralCachePolicy = .never,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Data, Error>) -> Void
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        if let record = cache[characteristicUUID], cachePolicy.isValid(time: record.time) {
            callback(.success(record.data))
            return
        }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        guard let characteristic = getCharacteristic(characteristicUUID) else {
            callback(.failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
            return
        }
        guard characteristic.properties.contains(.read) else {
            callback(.failure(BlePeripheralProxyError.readNotSupported(characteristicUUID: characteristicUUID)))
            return
        }
        
        characteristicReadRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout
        ) {
            $0.notify(.failure(BlePeripheralProxyError.readTimeout(characteristicUUID: characteristicUUID)))
        }
        
        guard !readingCharacteristics.contains(characteristicUUID) else {
            // Characteristic is already being read from the peripheral so avoid sending multiple read requests
            return
        }
        
        // Read from the peripheral.
        readingCharacteristics.insert(characteristicUUID)
        peripheral.readValue(for: characteristic)
        
    }
    
}

// MARK: - Characteristic write

extension BlePeripheralProxy {
    
    /// Returns the maximum amount of data, in bytes, that can be sent to a characteristic in a single write operation of a given type.
    ///
    /// - Parameter type: The type of write operation, specified by `CBCharacteristicWriteType`.
    /// - Returns: The maximum length, in bytes, that can be sent in a single write operation.
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        return peripheral.maximumWriteValueLength(for: type)
    }
    
    /// Writes a value to a specific characteristic and notifies the result through the provided callback.
    ///
    /// This method writes the specified data to the given characteristic and invokes the callback upon completion.
    /// If the write operation succeeds, the callback is passed a `Result` containing `.success`.
    /// In case of failure, the callback will contain an `Error`.
    ///
    /// - Parameters:
    ///   - data: The data to write to the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic to which the data should be written.
    ///   - timeout: The timeout for the characteristic write operation. Defaults to 10 seconds.
    ///   - callback: A closure that is executed when the write operation completes. The closure is passed a `Result` indicating whether the operation succeeded (`.success`) or failed with an `Error`.
    ///
    /// - Note: The write operation will attempt to complete within the specified timeout, after which it may fail if the peripheral does not respond in time.
    public func write(
        data: Data,
        to characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Void, Error>) -> Void
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        guard let characteristic = getCharacteristic(characteristicUUID) else {
            callback(.failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
            return
        }
        guard characteristic.properties.contains(.write) else {
            callback(.failure(BlePeripheralProxyError.writeNotSupported(characteristicUUID: characteristicUUID)))
            return
        }
        
        characteristicWriteRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout
        ) {
            $0.notify(.failure(BlePeripheralProxyError.writeTimeout(characteristicUUID: characteristicUUID)))
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        
    }
    
    /// Writes a value to a specific characteristic without triggering a response from the peripheral.
    ///
    /// This method writes the specified data to the given characteristic and does not wait for a response from the peripheral.
    /// If the write operation fails, an error is thrown.
    ///
    /// - Parameters:
    ///   - data: The data to write to the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic to which the data should be written.
    ///
    /// - Throws: `BlePeripheralProxyError.peripheralNotConnected` if the peripheral is not connected.
    /// - Throws: `BlePeripheralProxyError.characteristicNotFound` if the characteristic with the specified UUID cannot be found.
    /// - Throws: `BlePeripheralProxyError.writeNotSupported` if the characteristic does not support writing without a response.
    ///
    /// - Note: This method is useful for sending data where a response from the peripheral is not required, such as sending notifications or control commands.
    public func writeWithoutResponse(data: Data, to characteristicUUID: CBUUID) throws {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            throw BlePeripheralProxyError.peripheralNotConnected
        }
        guard let characteristic = getCharacteristic(characteristicUUID) else {
            throw BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)
        }
        guard characteristic.properties.contains(.writeWithoutResponse) else {
            throw BlePeripheralProxyError.writeNotSupported(characteristicUUID: characteristicUUID)
        }

        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)

    }
    
}

// MARK: - Characteristic notify

extension BlePeripheralProxy {
    
    /// Checks whether notification is enabled for a specific characteristic.
    ///
    /// This method verifies if the `isNotifying` flag is set for a characteristic on a connected peripheral.
    /// If the peripheral is not connected, the characteristic is not found, or the characteristic does not support notifications, the method will return a corresponding error via the callback.
    /// 
    /// - Parameters:
    ///   - characteristicUUID: The UUID of the characteristic for which to check the notification state.
    ///   - timeout: The timeout duration for the notification check operation. If the operation does not complete within this time, it will fail.
    ///   - callback: A closure to execute when the characteristic notification state is retrieved. The closure receives a `Result` indicating success or failure, with the current notification state as a success value.
    public func isNotifying(
        characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Bool, Error>) -> Void
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        guard let characteristic = getCharacteristic(characteristicUUID) else {
            callback(.failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
            return
        }
        guard characteristic.properties.contains(.notify) else {
            callback(.failure(BlePeripheralProxyError.notifyNotSupported(characteristicUUID: characteristicUUID)))
            return
        }
        
        callback(.success(characteristic.isNotifying))
        
    }
 
    /// Enables or disables notifications for a specific characteristic.
    ///
    /// This method updates the notification state for the given characteristic and executes the provided callback when the operation is complete.
    /// If notifications are already in the desired state, the callback is called immediately with the current state.
    ///
    /// - Parameters:
    ///   - enabled: `true` to enable notifications, `false` to disable notifications for the characteristic.
    ///   - characteristicUUID: The UUID of the characteristic for which to set the notification state.
    ///   - timeout: The timeout duration for the notification set operation. If the operation does not complete within this time, it will fail.
    ///   - callback: A closure to execute when the characteristic notification state is updated. The closure receives a `Result` indicating success or failure, with the current notification state as a success value.
    ///
    /// - Note: If the desired notification state is already set, the method will immediately return the current state without performing any further operations.
    public func setNotify(
        enabled: Bool,
        for characteristicUUID: CBUUID,
        timeout: DispatchTimeInterval = .seconds(10),
        callback: @escaping (Result<Bool, Error>) -> Void
    ) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        guard let characteristic = getCharacteristic(characteristicUUID) else {
            callback(.failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
            return
        }
        guard characteristic.properties.contains(.notify) else {
            callback(.failure(BlePeripheralProxyError.notifyNotSupported(characteristicUUID: characteristicUUID)))
            return
        }
        guard enabled != characteristic.isNotifying else {
            callback(.success(characteristic.isNotifying))
            return
        }
        
        characteristicNotifyRegistry.register(
            key: characteristicUUID,
            callback: callback,
            timeout: timeout
        ) {
            $0.notify(.failure(BlePeripheralProxyError.notifyTimeout(characteristicUUID: characteristicUUID)))
        }
        
        peripheral.setNotifyValue(enabled, for: characteristic)
        
    }
    
}

// MARK: - RSSI read

extension BlePeripheralProxy {

    /// Reads the RSSI (Received Signal Strength Indicator) value of the peripheral.
    ///
    /// This method attempts to read the RSSI value of the connected peripheral within a specified timeout period.
    ///
    /// - Parameters:
    ///   - timeout: The maximum time to wait for an RSSI read operation. Defaults to 10 seconds.
    ///   - callback: A closure that is called with the result of the RSSI read operation. The closure is passed a `Result` containing the RSSI value or an error if the read fails.
    public func readRSSI(timeout: DispatchTimeInterval = .seconds(10), callback: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
       
        rssiReadRegistry.register(callback: callback, timeout: timeout) {
            $0.notify(.failure(BlePeripheralProxyError.rssiReadTimeout))
        }
      
        peripheral.readRSSI()

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
                self?.peripheral.readRSSI()
            }
            rssiTimer?.resume()
        } else if !enabled && rssiTimer != nil  {
            rssiTimer?.cancel()
            rssiTimer = nil
        }
        
    }
    
}
