//
//  BlePeripheralManagerProxy+Services.swift
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
    
    /// Adds a service to the peripheral manager.
    ///
    /// Registers a `CBMutableService` with the peripheral manager, making the service available for centrals to discover and interact with.
    ///
    /// - Parameter service: A `CBMutableService` instance representing the service to add.
    public func add(_ service: CBMutableService) {
        lock.lock()
        defer { lock.unlock() }
        peripheralManager.add(service)
    }
    
    /// Adds a list of services to the peripheral manager.
    ///
    /// Registers a list of `CBMutableService` with the peripheral manager, making the all the services available for centrals to discover and interact with.
    ///
    /// - Parameter services: A list of `CBMutableService` instance representing the services to add.
    public func add(services: [CBMutableService]) {
        lock.lock()
        defer { lock.unlock() }
        for service in services {
            peripheralManager.add(service)
        }
    }

    /// Removes a service from the peripheral manager.
    ///
    /// Unregisters a previously added service, making it unavailable for centrals.
    ///
    /// - Parameter service: A `CBMutableService` instance representing the service to remove.
    public func remove(_ service: CBMutableService) {
        lock.lock()
        defer { lock.unlock() }
        peripheralManager.remove(service)
    }
    
    /// Removes a list services from the peripheral manager.
    ///
    /// Unregisters previously added services, making them unavailable for centrals.
    ///
    /// - Parameter services: A list of `CBMutableService` instance representing the services to remove.
    public func remove(services: [CBMutableService]) {
        lock.lock()
        defer { lock.unlock() }
        for service in services {
            peripheralManager.remove(service)
        }
    }

    /// Removes all services from the peripheral manager.
    ///
    /// This function clears all previously added services, ensuring no services are available for discovery by centrals.
    public func removeAllServices() {
        lock.lock()
        defer { lock.unlock() }
        peripheralManager.removeAllServices()
    }
    
}
