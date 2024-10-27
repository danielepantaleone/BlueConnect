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
public class BlePeripheralProxy: NSObject {
    
    // MARK: - Public properties
    
    /// The `BlePeripheral` instance this proxy manages.
    public let peripheral: BlePeripheral
    
    // MARK: - Publishers
    
    /// A publisher that emits when characteristics are discovered for a service.
    /// It emits a tuple containing the service and an array of characteristics.
    public lazy var didDiscoverCharacteristicsPublisher: AnyPublisher<(service: CBService, characteristics: [CBCharacteristic]), Never> = {
        didDiscoverCharacteristicsSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when services are discovered on the peripheral.
    /// It emits an array of discovered services.
    public lazy var didDiscoverServicesPublisher: AnyPublisher<[CBService], Never> = {
        didDiscoverServicesSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when the peripheral updates its name.
    /// It emits the updated name of the peripheral as a `String?`.
    public lazy var didUpdateNamePublisher: AnyPublisher<String?, Never> = {
        didUpdateNameSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when the notification state for a characteristic changes.
    /// It emits a tuple containing the characteristic and a `Bool` indicating whether notifications are enabled.
    public lazy var didUpdateNotificationStatePublisher: AnyPublisher<(characteristic: CBCharacteristic, enabled: Bool), Never> = {
        didUpdateNotificationStateSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits the updated RSSI (Received Signal Strength Indicator) value for the peripheral.
    /// It emits an `NSNumber` representing the RSSI.
    public lazy var didUpdateRSSIPublisher: AnyPublisher<NSNumber, Never> = {
        didUpdateRSSISubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when a characteristic's value has been updated.
    /// It emits a tuple containing the characteristic and the updated value as `Data`.
    public lazy var didUpdateValuePublisher: AnyPublisher<(characteristic: CBCharacteristic, data: Data), Never> = {
        didUpdateValueSubject.eraseToAnyPublisher()
    }()
    
    /// A publisher that emits when a characteristic write operation completes.
    /// It emits the characteristic that was written.
    public lazy var didWriteValuePublisher: AnyPublisher<CBCharacteristic, Never> = {
        didWriteValueSubject.eraseToAnyPublisher()
    }()
   
    // MARK: - Internal properties
    
    var cache: [CBUUID: BlePeripheralCacheRecord] = [:]
    var readingCharacteristics: Set<CBUUID> = []
    let mutex = RecursiveMutex()
    
    var characteristicReadCallbacks: [CBUUID: [(Result<Data, Error>) -> Void]] = [:]
    var characteristicReadTimers: [CBUUID: DispatchSourceTimer] = [:]
    var characteristicNotifyCallbacks: [CBUUID: [(Result<Bool, Error>) -> Void]] = [:]
    var characteristicNotifyTimers: [CBUUID: DispatchSourceTimer] = [:]
    var characteristicWriteCallbacks: [CBUUID: [(Result<Void, Error>) -> Void]] = [:]
    var characteristicWriteTimers: [CBUUID: DispatchSourceTimer] = [:]
    var discoverCharacteristicCallbacks: [CBUUID: [(Result<CBCharacteristic, Error>) -> Void]] = [:]
    var discoverCharacteristicTimers: [CBUUID: DispatchSourceTimer] = [:]
    var discoverServiceCallbacks: [CBUUID: [(Result<CBService, Error>) -> Void]] = [:]
    var discoverServiceTimers: [CBUUID: DispatchSourceTimer] = [:]

    lazy var didDiscoverCharacteristicsSubject: PassthroughSubject<(service: CBService, characteristics: [CBCharacteristic]), Never> = .init()
    lazy var didDiscoverServicesSubject: PassthroughSubject<[CBService], Never> = .init()
    lazy var didUpdateNameSubject: PassthroughSubject<String?, Never> = .init()
    lazy var didUpdateNotificationStateSubject: PassthroughSubject<(characteristic: CBCharacteristic, enabled: Bool), Never> = .init()
    lazy var didUpdateRSSISubject: PassthroughSubject<NSNumber, Never> = .init()
    lazy var didUpdateValueSubject: PassthroughSubject<(characteristic: CBCharacteristic, data: Data), Never> = .init()
    lazy var didWriteValueSubject: PassthroughSubject<CBCharacteristic, Never> = .init()
    
    // MARK: - Initialization
    
    /// Unavailable initializer.
    /// Use `init(peripheral:)` instead.
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
        mutex.lock()
        defer { mutex.unlock() }
        peripheral.peripheralDelegate = nil
        readingCharacteristics.removeAll()
        cache.removeAll()
        // Stop timers
        discoverServiceTimers.forEach { $1.cancel() }
        discoverServiceTimers.removeAll()
        discoverCharacteristicTimers.forEach { $1.cancel() }
        discoverCharacteristicTimers.removeAll()
        characteristicReadTimers.forEach { $1.cancel() }
        characteristicReadTimers.removeAll()
        characteristicWriteTimers.forEach { $1.cancel() }
        characteristicWriteTimers.removeAll()
        characteristicNotifyTimers.forEach { $1.cancel() }
        characteristicNotifyTimers.removeAll()
        // Notify callbacks
        discoverServiceCallbacks.values
            .flatMap { $0 }
            .forEach { $0(.failure(BlePeripheralProxyError.destroyed)) }
        discoverServiceCallbacks.removeAll()
        discoverCharacteristicCallbacks.values
            .flatMap { $0 }
            .forEach { $0(.failure(BlePeripheralProxyError.destroyed)) }
        discoverCharacteristicCallbacks.removeAll()
        characteristicReadCallbacks.values
            .flatMap { $0 }
            .forEach { $0(.failure(BlePeripheralProxyError.destroyed)) }
        characteristicReadCallbacks.removeAll()
        characteristicNotifyCallbacks.values
            .flatMap { $0 }
            .forEach { $0(.failure(BlePeripheralProxyError.destroyed)) }
        characteristicNotifyCallbacks.removeAll()
        characteristicWriteCallbacks.values
            .flatMap { $0 }
            .forEach { $0(.failure(BlePeripheralProxyError.destroyed)) }
        characteristicWriteCallbacks.removeAll()
        // Notify publishers
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
        return peripheral.services?.first(where: { $0.uuid == uuid })
    }
    
    /// Retrieves a characteristic by its UUID from the peripheral's services.
    ///
    /// - Parameter uuid: The UUID of the characteristic to retrieve.
    /// - Returns: The `CBCharacteristic` if found, otherwise `nil`.
    func getCharacteristic(_ uuid: CBUUID) -> CBCharacteristic? {
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
        guard let service = getService(serviceUUID) else {
            return nil
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == uuid }) else {
            return nil
        }
        return characteristic
    }
    
    /// Register a callback for a specific characteristic or service to the provided store.
    ///
    /// - Parameters:
    ///   - store: The dictionary storing arrays of callback closures associated with their respective UUIDs.
    ///   - uuid: The UUID of the characteristic or service.
    ///   - callback: A closure that will be invoked when a `Result<T, Error>` is available for the specified UUID.
    func registerCallback<T>(
        store: inout [CBUUID: [(Result<T, Error>) -> Void]],
        uuid: CBUUID,
        callback: @escaping (Result<T, Error>) -> Void
    ) {
        if store[uuid] == nil {
            store[uuid] = []
        }
        store[uuid]?.append(callback)
    }
    
    /// Notifies registered callbacks with a result for a specific characteristic or service.
    ///
    /// - Parameters:
    ///   - store: The dictionary holding the callbacks for the characteristic or service.
    ///   - uuid: The UUID of the characteristic or service.
    ///   - value: The result to pass to the callbacks.
    func notifyCallbacks<T>(
        store: inout [CBUUID: [(Result<T, Error>) -> Void]],
        uuid: CBUUID,
        value: Result<T, Error>
    ) {
        guard let callbacks = store[uuid] else {
            return
        }
        store[uuid] = []
        callbacks.forEach { $0(value) }
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
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        
        if let service = getService(serviceUUID) {
            callback(.success(service))
            return
        }
        
        registerCallback(
            store: &discoverServiceCallbacks,
            uuid: serviceUUID,
            callback: callback)
        
        discover(serviceUUIDs: [serviceUUID], timeout: timeout)
        
    }
    
    /// Initiates the discovery of a set of services, or discovers all available services if `nil` is specified as `serviceUUIDs`.
    ///
    /// The discovered services will trigger the `didDiscoverServicesPublisher` multiple times as services are discovered.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: The UUIDs of the services to discover, or `nil` to discover all services on the peripheral.
    public func discover(serviceUUIDs: [CBUUID]?) {
        discover(serviceUUIDs: serviceUUIDs, timeout: .never)
    }
    
    /// Initiates the discovery of a set of services, or discovers all available services if `nil` is specified as `serviceUUIDs`.
    ///
    /// The discovered services will trigger the `didDiscoverServicesPublisher` multiple times as services are discovered.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: The UUIDs of the services to discover, or `nil` to discover all services on the peripheral.
    ///   - timeout: The timeout for the service discovery operation. This is ignored if no service UUIDs are provided.
    func discover(serviceUUIDs: [CBUUID]?, timeout: DispatchTimeInterval) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard peripheral.state == .connected else {
            // Notify on the callbacks (for each provided service)
            serviceUUIDs?.forEach { serviceUUID in
                notifyCallbacks(
                    store: &discoverServiceCallbacks,
                    uuid: serviceUUID,
                    value: .failure(BlePeripheralProxyError.peripheralNotConnected))
            }
            return
        }
        
        guard let UUIDs = serviceUUIDs else {
            // Cannot lookup in cache if no UUID is provided => active search
            // Cannot start discovery timer if no UUID is provided
            peripheral.discoverServices(serviceUUIDs)
            return
        }
        
        let alreadyDiscovered = peripheral.services.emptyIfNil.filter { UUIDs.contains($0.uuid) }
        if !alreadyDiscovered.isEmpty {
            // Notify on the callbacks (for each service already discovered)
            alreadyDiscovered.forEach { service in
                notifyCallbacks(
                    store: &discoverServiceCallbacks,
                    uuid: service.uuid,
                    value: .success(service))
            }
        }
        
        // Discover the remaining ones
        let toDiscover = serviceUUIDs.emptyIfNil.filter { !alreadyDiscovered.map { $0.uuid }.contains($0) }
        if !toDiscover.isEmpty {
            
            startDiscoverServiceTimers(
                serviceUUIDs: toDiscover,
                timeout: timeout)
            
            peripheral.discoverServices(toDiscover)
            
        }
        
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
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard peripheral.state == .connected else {
            callback(.failure(BlePeripheralProxyError.peripheralNotConnected))
            return
        }
        
        guard getService(serviceUUID) != nil else {
            callback(.failure(BlePeripheralProxyError.serviceNotFound(serviceUUID: serviceUUID)))
            return
        }
        
        if let characteristic = getCharacteristic(characteristicUUID, serviceUUID: serviceUUID) {
            callback(.success(characteristic))
            return
        }
        
        registerCallback(
            store: &discoverCharacteristicCallbacks,
            uuid: characteristicUUID,
            callback: callback)
        
        discover(characteristicUUIDs: [characteristicUUID], in: serviceUUID, timeout: timeout)
        
    }
    
    /// Discover a set of characteristics for the provided service, or all available characteristics if `nil` is specified for `characteristicUUIDs`.
    /// The discovered characteristics will trigger notifications via the `didDiscoverCharacteristicsPublisher`, which can be triggered multiple times.
    /// If specific characteristics are not found, they will not be advertised, so using `discover(characteristicUUID:in:timeout:callback)` is recommended for specific use cases.
    ///
    /// - Parameters:
    ///   - characteristicUUIDs: An array of UUIDs representing the characteristics to discover, or `nil` to discover all characteristics for the service.
    ///   - serviceUUID: The UUID of the service containing the characteristics.
    public func discover(characteristicUUIDs: [CBUUID]?, in serviceUUID: CBUUID) {
        discover(characteristicUUIDs: characteristicUUIDs, in: serviceUUID, timeout: .never)
    }
    
    /// Discover a set of characteristics for the provided service, or all available characteristics if `nil` is specified for `characteristicUUIDs`.
    /// The discovered characteristics will be notified via the `didDiscoverCharacteristicsPublisher`, which can trigger multiple times during discovery.
    ///
    /// - Parameters:
    ///   - characteristicUUIDs: An array of UUIDs representing the characteristics to discover, or `nil` to discover all characteristics for the service.
    ///   - serviceUUID: The UUID of the service containing the characteristics.
    ///   - timeout: The timeout duration for the characteristics discovery operation. If no characteristic UUIDs are provided, the `timeout` parameter is ignored.
    func discover(characteristicUUIDs: [CBUUID]?, in serviceUUID: CBUUID, timeout: DispatchTimeInterval) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard peripheral.state == .connected else {
            characteristicUUIDs?.forEach { characteristicUUID in
                notifyCallbacks(
                    store: &discoverCharacteristicCallbacks,
                    uuid: characteristicUUID,
                    value: .failure(BlePeripheralProxyError.peripheralNotConnected))
            }
            return
        }
        
        guard let service = getService(serviceUUID) else {
            characteristicUUIDs?.forEach { characteristicUUID in
                notifyCallbacks(
                    store: &discoverCharacteristicCallbacks,
                    uuid: characteristicUUID,
                    value: .failure(BlePeripheralProxyError.serviceNotFound(serviceUUID: serviceUUID)))
            }
            return
        }
        
        guard let UUIDs = characteristicUUIDs else {
            // Cannot lookup in cache if no UUID is provided => active search
            // Cannot start discovery timer if no UUID is provided
            peripheral.discoverCharacteristics(nil, for: service)
            return
        }
        
        let alreadyDiscovered = service.characteristics.emptyIfNil.filter { UUIDs.contains($0.uuid) }
        if !alreadyDiscovered.isEmpty {
            // Notify on the callbacks (for each characteristic already discovered)
            alreadyDiscovered.forEach { characteristic in
                notifyCallbacks(
                    store: &discoverCharacteristicCallbacks,
                    uuid: characteristic.uuid,
                    value: .success(characteristic))
            }
        }
        
        // Discover the remaining ones
        let toDiscover = characteristicUUIDs.emptyIfNil.filter { !alreadyDiscovered.map { $0.uuid }.contains($0) }
        if !toDiscover.isEmpty {
            
            startDiscoverCharacteristicTimers(
                characteristicUUIDs: toDiscover,
                timeout: timeout)
            
            peripheral.discoverCharacteristics(toDiscover, for: service)
            
        }
        
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
        
        mutex.lock()
        defer { mutex.unlock() }
        
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
        
        registerCallback(
            store: &characteristicReadCallbacks,
            uuid: characteristicUUID,
            callback: callback)
        
        startCharacteristicReadTimer(
            characteristicUUID: characteristicUUID,
            timeout: timeout)
        
        guard !readingCharacteristics.contains(characteristicUUID) else {
            // Characteristic is already being read from the peripheral so avoid sending multiple read requests
            return
        }
        
        // Read from the peripheral
        readingCharacteristics.insert(characteristicUUID)
        peripheral.readValue(for: characteristic)
        
    }
    
}

// MARK: - Characteristic write

extension BlePeripheralProxy {
    
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
        
        mutex.lock()
        defer { mutex.unlock() }
        
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
        
        registerCallback(
            store: &characteristicWriteCallbacks,
            uuid: characteristicUUID,
            callback: callback)
        
        startCharacteristicWriteTimer(
            characteristicUUID: characteristicUUID,
            timeout: timeout)
        
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
        
        mutex.lock()
        defer { mutex.unlock() }
        
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
        
        mutex.lock()
        defer { mutex.unlock() }
        
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
        
        registerCallback(
            store: &characteristicNotifyCallbacks,
            uuid: characteristicUUID,
            callback: callback)
        
        startCharacteristicNotifyTimer(
            characteristicUUID: characteristicUUID,
            timeout: timeout)
        
        peripheral.setNotifyValue(enabled, for: characteristic)
        
    }
    
}

// MARK: - Timers

extension BlePeripheralProxy {
    
    func startDiscoverCharacteristicTimers(characteristicUUIDs: [CBUUID], timeout: DispatchTimeInterval) {
        guard timeout != .never else { return }
        mutex.lock()
        defer { mutex.unlock() }
        for characteristicUUID in characteristicUUIDs {
            discoverCharacteristicTimers[characteristicUUID]?.cancel()
            discoverCharacteristicTimers[characteristicUUID] = DispatchSource.makeTimerSource()
            discoverCharacteristicTimers[characteristicUUID]?.schedule(deadline: .now() + timeout, repeating: .never)
            discoverCharacteristicTimers[characteristicUUID]?.setEventHandler { [weak self] in
                guard let self else { return }
                mutex.lock()
                defer { mutex.unlock() }
                discoverCharacteristicTimers[characteristicUUID]?.cancel()
                discoverCharacteristicTimers[characteristicUUID] = nil
                notifyCallbacks(
                    store: &discoverCharacteristicCallbacks,
                    uuid: characteristicUUID,
                    value: .failure(BlePeripheralProxyError.characteristicNotFound(characteristicUUID: characteristicUUID)))
            }
            discoverCharacteristicTimers[characteristicUUID]?.resume()
        }
    }
    
    func startDiscoverServiceTimers(serviceUUIDs: [CBUUID], timeout: DispatchTimeInterval) {
        guard timeout != .never else { return }
        mutex.lock()
        defer { mutex.unlock() }
        for serviceUUID in serviceUUIDs {
            discoverServiceTimers[serviceUUID]?.cancel()
            discoverServiceTimers[serviceUUID] = DispatchSource.makeTimerSource()
            discoverServiceTimers[serviceUUID]?.schedule(deadline: .now() + timeout, repeating: .never)
            discoverServiceTimers[serviceUUID]?.setEventHandler { [weak self] in
                guard let self else { return }
                mutex.lock()
                defer { mutex.unlock() }
                discoverServiceTimers[serviceUUID]?.cancel()
                discoverServiceTimers[serviceUUID] = nil
                notifyCallbacks(
                    store: &discoverServiceCallbacks,
                    uuid: serviceUUID,
                    value: .failure(BlePeripheralProxyError.serviceNotFound(serviceUUID: serviceUUID)))
            }
            discoverServiceTimers[serviceUUID]?.resume()
        }
    }
    
    func startCharacteristicReadTimer(characteristicUUID: CBUUID, timeout: DispatchTimeInterval) {
        guard timeout != .never else { return }
        mutex.lock()
        defer { mutex.unlock() }
        characteristicReadTimers[characteristicUUID]?.cancel()
        characteristicReadTimers[characteristicUUID] = DispatchSource.makeTimerSource()
        characteristicReadTimers[characteristicUUID]?.schedule(deadline: .now() + timeout, repeating: .never)
        characteristicReadTimers[characteristicUUID]?.setEventHandler { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            characteristicReadTimers[characteristicUUID]?.cancel()
            characteristicReadTimers[characteristicUUID] = nil
            notifyCallbacks(
                store: &characteristicReadCallbacks,
                uuid: characteristicUUID,
                value: .failure(BlePeripheralProxyError.readTimeout(characteristicUUID: characteristicUUID)))
        }
        characteristicReadTimers[characteristicUUID]?.resume()
    }
    
    func startCharacteristicNotifyTimer(characteristicUUID: CBUUID, timeout: DispatchTimeInterval) {
        guard timeout != .never else { return }
        mutex.lock()
        defer { mutex.unlock() }
        characteristicNotifyTimers[characteristicUUID]?.cancel()
        characteristicNotifyTimers[characteristicUUID] = DispatchSource.makeTimerSource()
        characteristicNotifyTimers[characteristicUUID]?.schedule(deadline: .now() + timeout, repeating: .never)
        characteristicNotifyTimers[characteristicUUID]?.setEventHandler { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            characteristicNotifyTimers[characteristicUUID]?.cancel()
            characteristicNotifyTimers[characteristicUUID] = nil
            notifyCallbacks(
                store: &characteristicNotifyCallbacks,
                uuid: characteristicUUID,
                value: .failure(BlePeripheralProxyError.notifyTimeout(characteristicUUID: characteristicUUID)))
        }
        characteristicNotifyTimers[characteristicUUID]?.resume()
    }
    
    func startCharacteristicWriteTimer(characteristicUUID: CBUUID, timeout: DispatchTimeInterval) {
        guard timeout != .never else { return }
        mutex.lock()
        defer { mutex.unlock() }
        characteristicWriteTimers[characteristicUUID]?.cancel()
        characteristicWriteTimers[characteristicUUID] = DispatchSource.makeTimerSource()
        characteristicWriteTimers[characteristicUUID]?.schedule(deadline: .now() + timeout, repeating: .never)
        characteristicWriteTimers[characteristicUUID]?.setEventHandler { [weak self] in
            guard let self else { return }
            mutex.lock()
            defer { mutex.unlock() }
            characteristicWriteTimers[characteristicUUID]?.cancel()
            characteristicWriteTimers[characteristicUUID] = nil
            notifyCallbacks(
                store: &characteristicWriteCallbacks,
                uuid: characteristicUUID,
                value: .failure(BlePeripheralProxyError.writeTimeout(characteristicUUID: characteristicUUID)))
        }
        characteristicWriteTimers[characteristicUUID]?.resume()
    }
    
    func stopDiscoverCharacteristicTimers(characteristicUUIDs: [CBUUID]) {
        mutex.lock()
        defer { mutex.unlock() }
        for characteristicUUID in characteristicUUIDs {
            discoverCharacteristicTimers[characteristicUUID]?.cancel()
            discoverCharacteristicTimers[characteristicUUID] = nil
        }
    }
    
    func stopDiscoverServiceTimers(serviceUUIDs: [CBUUID]) {
        mutex.lock()
        defer { mutex.unlock() }
        for serviceUUID in serviceUUIDs {
            discoverServiceTimers[serviceUUID]?.cancel()
            discoverServiceTimers[serviceUUID] = nil
        }
    }
    
    func stopCharacteristicReadTimer(characteristicUUID: CBUUID) {
        mutex.lock()
        defer { mutex.unlock() }
        characteristicReadTimers[characteristicUUID]?.cancel()
        characteristicReadTimers[characteristicUUID] = nil
    }
    
    func stopCharacteristicNotifyTimer(characteristicUUID: CBUUID) {
        mutex.lock()
        defer { mutex.unlock() }
        characteristicNotifyTimers[characteristicUUID]?.cancel()
        characteristicNotifyTimers[characteristicUUID] = nil
    }
    
    func stopCharacteristicWriteTimer(characteristicUUID: CBUUID) {
        mutex.lock()
        defer { mutex.unlock() }
        characteristicWriteTimers[characteristicUUID]?.cancel()
        characteristicWriteTimers[characteristicUUID] = nil
    }
    
}
