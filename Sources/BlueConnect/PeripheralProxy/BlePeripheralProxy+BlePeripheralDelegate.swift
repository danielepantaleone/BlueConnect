//
//  BlePeripheralProxy+CBPeripheralDelegate.swift
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

@preconcurrency import CoreBluetooth
import Foundation

extension BlePeripheralProxy: BlePeripheralDelegate {
    
    public func blePeripheralDidUpdateName(_ peripheral: BlePeripheral) {
        didUpdateNameSubject.send(peripheral.name)
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didDiscoverServices error: Error?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        guard error == nil else {
            // If the discovery is unsuccessful, the error parameter returns the cause of the failure.
            // However we will be missing the UUID of the service for which the error was generated since
            // we won't find it among the peripheral services property, hence we discard the error and
            // rely only on timeouts to notify errors to the caller.
            return
        }
        
        let services = peripheral.services.emptyIfNil
        let serviceUUIDs = services.map { $0.uuid }
        
        // Stop all the discover timers for all the services that have been discovered
        stopDiscoverServiceTimers(serviceUUIDs: serviceUUIDs)
        
        // Notify on the publisher
        didDiscoverServicesSubject.send(services)
        
        // Notify on the callbacks (for each service already discovered)
        services.forEach { service in
            notifyCallbacks(
                store: &discoverServiceCallbacks,
                key: service.uuid,
                value: .success(service))
        }
    
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
      
        mutex.lock()
        defer { mutex.unlock() }
        
        guard error == nil else {
            // If the discovery is unsuccessful, the error parameter returns the cause of the failure.
            // However we will be missing the UUID of the characteristic for which the error was generated
            // since we won't find it among the service characteristics property, hence we discard the error
            // and rely only on timeouts to notify errors to the caller.
            return
        }
        
        let characteristics = service.characteristics.emptyIfNil
        let characteristicUUIDs = characteristics.map { $0.uuid }
        
        // Stop all the discover timers for all the characteristics that have been discovered
        stopDiscoverCharacteristicTimers(characteristicUUIDs: characteristicUUIDs)
        
        // Notify on the publisher
        didDiscoverCharacteristicsSubject.send((service, characteristics))
        
        // Notify on the callbacks (for each service already discovered)
        characteristics.forEach { characteristic in
            notifyCallbacks(
                store: &discoverCharacteristicCallbacks,
                key: characteristic.uuid,
                value: .success(characteristic))
        }
        
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        didUpdateRSSISubject.send(RSSI)
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
      
        mutex.lock()
        defer { mutex.unlock() }
        
        stopCharacteristicNotifyTimer(characteristicUUID: characteristic.uuid)
        
        // Notify any error on awaiting callbacks
        if let error {
            notifyCallbacks(
                store: &characteristicNotifyCallbacks,
                key: characteristic.uuid,
                value: .failure(error))
            return
        }
        
        // Notify on the publisher
        didUpdateNotificationStateSubject.send((characteristic, characteristic.isNotifying))

        // Notify callbacks
        notifyCallbacks(
            store: &characteristicNotifyCallbacks,
            key: characteristic.uuid,
            value: .success(characteristic.isNotifying))
        
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        // Stop reading timer and remove currently reading characteristics even if it errored
        readingCharacteristics.remove(characteristic.uuid)
        stopCharacteristicReadTimer(characteristicUUID: characteristic.uuid)
        
        // Notify any error on awaiting callbacks
        if let error {
            notifyCallbacks(
                store: &characteristicReadCallbacks,
                key: characteristic.uuid,
                value: .failure(error))
            return
        }
        
        // Notify missing data error on awaiting callbacks
        guard let data = characteristic.value else {
            notifyCallbacks(
                store: &characteristicReadCallbacks,
                key: characteristic.uuid,
                value: .failure(BlePeripheralProxyError.characteristicDataIsNil(characteristicUUID: characteristic.uuid)))
            return
        }
        
        // Save to local cache (will be reused in the future according with the provided read policy)
        cache[characteristic.uuid] = .init(data: data)
        
        // Notify on the publisher
        didUpdateValueSubject.send((characteristic, data))

        // Notify callbacks
        notifyCallbacks(
            store: &characteristicReadCallbacks,
            key: characteristic.uuid,
            value: .success(data))

    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        mutex.lock()
        defer { mutex.unlock() }
        
        stopCharacteristicWriteTimer(characteristicUUID: characteristic.uuid)
        
        // Notify any error on awaiting callbacks
        if let error {
            notifyCallbacks(
                store: &characteristicWriteCallbacks,
                key: characteristic.uuid,
                value: .failure(error))
            return
        }
        
        // Notify on the publisher
        didWriteValueSubject.send(characteristic)
        
        // Notify callbacks
        notifyCallbacks(
            store: &characteristicWriteCallbacks,
            key: characteristic.uuid,
            value: .success(()))
        
    }
    
}
