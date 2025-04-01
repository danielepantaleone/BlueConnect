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
        
        lock.lock()
        defer { lock.unlock() }
        
        guard error == nil else {
            // If the discovery is unsuccessful, the error parameter returns the cause of the failure.
            // However we will be missing the UUID of the service for which the error was generated since
            // we won't find it among the peripheral services property, hence we discard the error and
            // rely only on timeouts to notify errors to the caller.
            return
        }
        
        // Local store discovered services.
        let services = peripheral.services.emptyIfNil
        
        // Notify on the publisher.
        didDiscoverServicesSubject.send(services)
        
        // Notify on the callbacks (for each service already discovered).
        services.forEach { service in
            discoverServiceRegistry.notify(
                key: service.uuid,
                value: .success(service))
        }
    
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
      
        lock.lock()
        defer { lock.unlock() }
        
        guard error == nil else {
            // If the discovery is unsuccessful, the error parameter returns the cause of the failure.
            // However we will be missing the UUID of the characteristic for which the error was generated
            // since we won't find it among the service characteristics property, hence we discard the error
            // and rely only on timeouts to notify errors to the caller.
            return
        }
        
        // Local store discovered characteristics.
        let characteristics = service.characteristics.emptyIfNil
        
        // Notify on the publisher.
        didDiscoverCharacteristicsSubject.send((service, characteristics))
        
        // Notify on the callbacks (for each service already discovered).
        characteristics.forEach { characteristic in
            discoverCharacteristicRegistry.notify(
                key: characteristic.uuid,
                value: .success(characteristic))
        }
        
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Notify any error on awaiting callbacks.
        if let error {
            rssiReadRegistry.notifyAll(.failure(error))
            return
        }
        
        // A value of 127 dBm (or 0x7F in hexadecimal) is a special indicator, meaning the RSSI reading is unavailable.
        if RSSI.intValue == -127 {
            rssiReadRegistry.notifyAll(.failure(BlePeripheralProxyError.rssiReadNotAvailable))
            return
        }
        
        // Notify on the publisher.
        didUpdateRSSISubject.send(RSSI)
        
        // Notify callbacks.
        rssiReadRegistry.notifyAll(.success(RSSI))
        
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
      
        lock.lock()
        defer { lock.unlock() }
                
        // Notify any error on awaiting callbacks.
        if let error {
            characteristicNotifyRegistry.notify(
                key: characteristic.uuid,
                value: .failure(error))
            return
        }
        
        // Notify on the publisher.
        didUpdateNotificationStateSubject.send((characteristic, characteristic.isNotifying))

        // Notify callbacks.
        characteristicNotifyRegistry.notify(
            key: characteristic.uuid,
            value: .success(characteristic.isNotifying))
        
    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        lock.lock()
        defer { lock.unlock() }
        
        // Stop reading timer and remove currently reading characteristics even if it errored.
        readingCharacteristics.remove(characteristic.uuid)
        
        // Notify any error on awaiting callbacks.
        if let error {
            characteristicReadRegistry.notify(
                key: characteristic.uuid,
                value: .failure(error))
            return
        }
        
        // Notify missing data error on awaiting callbacks.
        guard let data = characteristic.value else {
            characteristicReadRegistry.notify(
                key: characteristic.uuid,
                value: .failure(BlePeripheralProxyError.characteristicDataIsNil(characteristicUUID: characteristic.uuid)))
           return
        }
        
        // Save to local cache (will be reused in the future according with the provided read policy).
        cache[characteristic.uuid] = .init(data: data)

        // Notify on the publisher.
        didUpdateValueSubject.send((characteristic, data))

        // Notify callbacks.
        characteristicReadRegistry.notify(
            key: characteristic.uuid,
            value: .success(data))

    }
    
    public func blePeripheral(_ peripheral: BlePeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        lock.lock()
        defer { lock.unlock() }
            
        // Notify any error on awaiting callbacks.
        if let error {
            characteristicWriteRegistry.notify(
                key: characteristic.uuid,
                value: .failure(error))
            return
        }
        
        // Notify on the publisher.
        didWriteValueSubject.send(characteristic)
        
        // Notify callbacks.
        characteristicWriteRegistry.notify(
            key: characteristic.uuid,
            value: .success(()))
        
    }
    
}
