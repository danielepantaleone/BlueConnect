![Logo](https://github.com/danielepantaleone/BlueConnect/blob/master/Banner.png?raw=true)

[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdanielepantaleone%2FBlueConnect%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/danielepantaleone/BlueConnect)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdanielepantaleone%2FBlueConnect%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/danielepantaleone/BlueConnect)
![Cocoapods](https://img.shields.io/cocoapods/v/BlueConnect)
![SPM](https://img.shields.io/github/v/release/danielepantaleone/BlueConnect)
![License](https://img.shields.io/github/license/danielepantaleone/BlueConnect)
![CI](https://img.shields.io/github/actions/workflow/status/danielepantaleone/BlueConnect/swift-tests.yml)

BlueConnect is a Swift framework built on top of CoreBluetooth, designed to simplify interaction with Bluetooth Low Energy (BLE) peripherals. 
By wrapping Core Bluetooth functionalities, BlueConnect provides a modern approach to BLE communication. 
It leverages asynchronous programming models, allowing you to interact with peripherals using either traditional callbacks or Swift concurrency with async/await. 

Additionally, BlueConnect supports event notifications through [Combine](https://developer.apple.com/documentation/combine)  publishers, offering a more streamlined and reactive way to handle BLE events. 
By leveraging Swift protocols, BlueConnect also facilitates unit testing, making it easier to build testable libraries and apps that interact with BLE peripherals. 
This combination of asynchronous communication, event-driven architecture, and testability ensures a highly flexible and modern BLE development experience.

## Table of contents

* [Feature highlights](#feature-highlights)
* [Usage](#usage)
    * [Scanning for peripherals](#scanning-for-peripherals)
    * [Connecting a peripheral](#connecting-a-peripheral)
    * [Disconnecting a peripheral](#disconnecting-a-peripheral)
    * [Reading connected peripheral RSSI](#reading-connected-peripheral-rssi)
    * [Enabling RSSI notify on a connected peripheral](#enabling-rssi-notify-on-a-connected-peripheral)
    * [Reading a characteristic](#reading-a-characteristic)
    * [Writing a characteristic](#writing-a-characteristic)
    * [Enabling notify on a characteristic](#enabling-notify-on-a-characteristic)
* [Providing unit tests in your codebase](#providing-unit-tests-in-your-codebase)
* [Installation](#installation)
    * [Cocoapods](#cocoapods)
    * [Swift package manager](#swift-package-manager)
* [Documentation](https://danielepantaleone.github.io/BlueConnect/documentation/blueconnect/)
* [Contributing](#contributing)
* [License](#license)

## Feature Highlights

- [x] Works on iOS and macOS.  
- [x] Fully covered by unit tests.  
- [x] Uses closures and async/await instead of delegates.  
- [x] Sends events via [Combine](https://developer.apple.com/documentation/combine) publishers.  
- [x] Handles **CBPeripheral** connection timeouts.  
- [x] Handles **CBPeripheral** characteristics operation timeouts.  
- [x] Accesses **CBPeripheral** characteristics without managing its data.  
- [x] Offers optional cache for static **CBPeripheral** data.  
- [x] Auto-discovers services/characteristics on operation.  
- [x] Publishes when **CBPeripheralManager** stops advertising.  
- [x] Routes failed **CBCentralManager** connections to the right callbacks.  
- [x] Supports BLE mocks for easier unit testing.

## Usage

BlueConnect delegates its functionality to several proxies:

- **BleCentralManagerProxy**: Wraps **CBCentralManager** for connecting, disconnecting, and scanning.  
- **BlePeripheralManagerProxy**: Wraps **CBPeripheralManager** for advertising and handling BLE requests. 
- **BlePeripheralProxy**: Wraps **CBPeripheral** for communication and data transfer.

Since communication with BLE peripherals requires encoding and decoding raw data, BlueConnect simplifies this interaction by offering various proxy protocols that wrap around **BlePeripheralProxy**. You can create custom proxies by conforming to these protocols, enabling you to perform operations like reading, writing, and enabling notifications on BLE peripheral characteristics:

- **BleCharacteristicProxy**: The base proxy for discovering characteristics.
- **BleCharacteristicReadProxy**: A proxy for reading data from a characteristic.
- **BleCharacteristicWriteProxy**: A proxy for writing data to a characteristic.
- **BleCharacteristicWriteWithoutResponseProxy**: A proxy for writing data to a characteristic without awaiting a response from the BLE peripheral.
- **BleCharacteristicNotifyProxy**: A proxy for enabling notifications on a characteristic.

### Scanning for peripherals

You can start scanning for BLE peripherals by calling `scanForPeripherals` on the **BleCentralManagerProxy**. This method allows you to provide BLE scan options, which are passed directly to the underlying **CBCentralManager**. You can also specify an optional timeout (defaulting to 60 seconds if not provided). The method returns a publisher that you can use to listen for discovered BLE peripherals, along with completion or 
failure events.

```swift
import BlueConnect

let centralManagerProxy = BleCentralManagerProxy()

do {
    try await centralManagerProxy.waitUntilReady()
    let subscription = centralManagerProxy.scanForPeripherals(timeout: .seconds(30))
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                // This is called when the peripheral scan is completed or upon scan failure.
                switch completion {
                    case .finished:
                        print("peripheral scan completed successfully")
                    case .failure(let error):
                        print("peripheral scan terminated with error: \(error)")
                }
            },
            receiveValue: { peripheral, advertisementData, RSSI in 
                // This is called multiple times for every discovered peripheral.
                print("peripheral '\(peripheral.identifier)' was discovered")
            }
        )
} catch {
    print("peripheral scan failed with error: \(error)")
}
```

You can alternatively make use of Swift Concurrency async stream to iterate over discovered peripherals:

```swift
import BlueConnect

let centralManagerProxy = BleCentralManagerProxy()

do {
    try await centralManagerProxy.waitUntilReady()
    for try await result in bleCentralManagerProxy.scanForPeripherals(timeout: .seconds(30)) {
        print("peripheral '\(result.peripheral.identifier)' was discovered")
    }
} catch {
    print("peripheral scan failed with error: \(error)")
}
```

The peripheral scan will automatically stop if a timeout is specified. However, you can also manually stop the scan at any time by calling `stopScan` on the **BleCentralManagerProxy**.

### Connecting a peripheral

To connect to a BLE peripheral, use the `connect` method on the **BleCentralManagerProxy**. You can provide connection options that will be forwarded to the underlying **CBCentralManager**. Additionally, you have the option to specify a timeout (defaulting to no timeout if not provided). The establishment of the connection will also be notified through the Combine publishers, allowing you 
to react to the connection status.

```swift
import BlueConnect

let centralManagerProxy = BleCentralManagerProxy()

// You can optionally subscribe a publisher to be notified when a connection is established.
let subscription1 = centralManagerProxy.didConnectPublisher
    .receive(on: DispatchQueue.main)
    .sink { peripheral in 
        print("peripheral '\(peripheral.identifier)' connected")
    }

// You can optionally subscribe a publisher to be notified when a connection attempt fails.
let subscription2 = centralManagerProxy.didFailToConnectPublisher
    .receive(on: DispatchQueue.main)
    .sink { peripheral, error in 
        print("peripheral '\(peripheral.identifier)' failed to connect with error: \(error)")
    }

do {
    // The following will try to establish a connection to a BLE peripheral for at most 60 seconds.
    // If the connection cannot be established within the specified amount of time, the connection 
    // attempt is dropped and notified by raising an appropriate error.
    try await centralManagerProxy.waitUntilReady()
    try await centralManagerProxy.connect(
        peripheral: peripheral,
        options: nil,
        timeout: .seconds(60))
    print("peripheral '\(peripheral.identifier)' connected")
} catch {
    print("peripheral connection failed with error: \(error)")
}
```

### Disconnecting a peripheral

To disconnect a connected BLE peripheral, use the `disconnect` method on the **BleCentralManagerProxy**. The disconnection event will be notified through the Combine publisher, enabling you to respond to changes in the connection status.

```swift
import BlueConnect

let centralManagerProxy = BleCentralManagerProxy()

// You can optionally subscribe a publisher to be notified when a peripheral is disconnected.
let subscription = centralManagerProxy.didDisconnectPublisher
    .receive(on: DispatchQueue.main)
    .sink { peripheral in 
        print("peripheral '\(peripheral.identifier)' disconnected")
    }

do {
    // The following will disconnect a BLE peripheral.
    try await centralManagerProxy.waitUntilReady()
    try await centralManagerProxy.disconnect(peripheral: peripheral)
    print("peripheral '\(peripheral.identifier)' disconnected")
} catch {
    print("peripheral disconnection failed with error: \(error)")
}
```

### Reading connected peripheral RSSI

To read connected peripheral RSSI you can use the `readRSSI` method of the `BlePeripheralProxy`.

```swift
import BlueConnect

let peripheralProxy = BlePeripheralProxy(peripheral: peripheral)

// You can optionally subscribe a publisher to be triggered when the RSSI value is read.
let subscription = peripheralProxy.didUpdateRSSIPublisher
    .receive(on: DispatchQueue.main)
    .sink { value in 
        print("RSSI: \(value)")
    }

do {
    // The following will read the RSSI value from a connected peripheral.
    let value = try await peripheralProxy.readRSSI(timeout: .seconds(10))
    print("RSSI: \(value)")
} catch {
    print("failed to read peripheral RSSI with error: \(error)")
}
```

### Enabling RSSI notify on a connected peripheral

To enable RSSI signal notify on a connected peripheral `setRSSINotify` method of the `BlePeripheralProxy`.

```swift
import BlueConnect

let peripheralProxy = BlePeripheralProxy(peripheral: peripheral)

// You can subscribe a publisher to be triggered when the RSSI value is notified.
let subscription = peripheralProxy.didUpdateRSSIPublisher
    .receive(on: DispatchQueue.main)
    .sink { value in 
        print("RSSI: \(value)")
    }

do {
    // The following will enable RSSI notify on the connected peripheral. Notification will occur every 2 seconds 
    try await peripheralProxy.setRSSINotify(enabled: true, rate: .seconds(2))
} catch {
    print("failed to enable RSSI notify on connected peripheral with error: \(error)")
}
```

### Reading a characteristic

To read a characteristic, you can create your own proxy by conforming to the **BleCharacteristicReadProxy** protocol, which provides the necessary functionality for reading data from a characteristic.

```swift
import BlueConnect
import CoreBluetooth

// Declare your type conforming to the BleCharacteristicReadProxy protocol.
struct SerialNumberProxy: BleCharacteristicReadProxy {
    
    typealias ValueType = String
    
    let characteristicUUID: CBUUID = CBUUID(string: "2A25")
    let serviceUUID: CBUUID = CBUUID(string: "180A")

    weak var peripheralProxy: BlePeripheralProxy?
    
    init(peripheralProxy: BlePeripheralProxy) {
        self.peripheralProxy = peripheralProxy
    }
    
    func decode(_ data: Data) throws -> String {
        return String(decoding: data, as: UTF8.self)
    }
        
}

let peripheralProxy = BlePeripheralProxy(peripheral: peripheral)
let serialNumberProxy = SerialNumberProxy(peripheralProxy: peripheralProxy)

// You can optionally subscribe a publisher to be notified when data is read from the characteristic.
// The publisher sink method won't be triggered when reading data from local cache.
let subscription = serialNumberProxy.didUpdateValuePublisher
    .receive(on: DispatchQueue.main)
    .sink { serialNumber in 
        print("serial number is \(serialNumber)")
     }

do {
    // The following will read the serial number of the characteristic.
    // If the serial number characteristic, or the service backing the characteristic, has not been discovered yet, 
    // a silent discovery is performed before attempting to read data from the characteristic.
    let serialNumber = try await serialNumberProxy.read(cachePolicy: .always, timeout: .seconds(10))
    print("serial number is \(serialNumber)")
} catch {
    print("failed to read serial number with error: \(error)")
}
```

### Writing a characteristic

To write a characteristic, you can create your own proxy by conforming to the **BleCharacteristicWriteProxy** protocol, which provides the necessary functionality for writing data to a characteristic.

```swift
import BlueConnect
import CoreBluetooth

// Declare your type conforming to the BleCharacteristicWriteProxy protocol.
struct PinProxy: BleCharacteristicWriteProxy {
    
    typealias ValueType = String
    
    let characteristicUUID: CBUUID = CBUUID(string: "5A8F2E01-58D9-4B0B-83B8-843402E49293")
    let serviceUUID: CBUUID = CBUUID(string: "C5405A74-7C07-4702-A631-9D5EBF007DAE")

    weak var peripheralProxy: BlePeripheralProxy?
    
    init(peripheralProxy: BlePeripheralProxy) {
        self.peripheralProxy = peripheralProxy
    }
    
    func encode(_ value: String) throws -> Data {
        return Data(value.utf8)
    }
        
}

let peripheralProxy = BlePeripheralProxy(peripheral: peripheral)
let pinProxy = PinProxy(peripheralProxy: peripheralProxy)

// You can optionally subscribe a publisher to be notified when data is written to the characteristic.
let subscription = pinProxy.didWriteValuePublisher
    .receive(on: DispatchQueue.main)
    .sink {  
        print("data was written to the characteristic")
     }

do {
    // The following will write the PIN to the PIN characteristic.
    // If the PIN characteristic, or the service backing the PIN characteristic, has not been discovered yet, 
    // a silent discovery is performed before attempting to write data to the characteristic.
    try await pinProxy.write(value: "1234", timeout: .seconds(10))
    print("data was written to the characteristic")
} catch {
    print("failed to write data to the characteristic with error: \(error)")
}
```

### Enabling notify on a characteristic

To be notified when characteristic data is updated, you can create your own proxy by conforming to the **BleCharacteristicNotifyProxy** and **BleCharacteristicReadProxy** protocols. The **BleCharacteristicNotifyProxy** provides the necessary functionality to enable data notify on the characteristic while the **BleCharacteristicReadProxy** provides the necessary functionality for receiving data from a characteristic.

```swift
import BlueConnect
import CoreBluetooth

// Declare your type conforming to the BleCharacteristicNotifyProxy and BleCharacteristicReadProxy protocols.
// You can omit BleCharacteristicReadProxy if you are not interested in receiving characteristic data and you just want
// to toggle the notification status for a characteristic.
struct HeartRateProxy: BleCharacteristicReadProxy, BleCharacteristicNotifyProxy {
    
    typealias ValueType = Int
    
    let characteristicUUID: CBUUID = CBUUID(string: "2A37")
    let serviceUUID: CBUUID = CBUUID(string: "180D")

    weak var peripheralProxy: BlePeripheralProxy?
    
    init(peripheralProxy: BlePeripheralProxy) {
        self.peripheralProxy = peripheralProxy
    }
    
    func decode(_ data: Data) throws -> Int {
        return Int(data.first ?? 0x00)
    }
        
}

let peripheralProxy = BlePeripheralProxy(peripheral: peripheral)
let heartRateProxy = HeartRateProxy(peripheralProxy: peripheralProxy)

// You can optionally subscribe a publisher to be triggered when the notify flag is changed.
let subscription1 = heartRateProxy.didUpdateNotificationStatePublisher
    .receive(on: DispatchQueue.main)
    .sink { enabled in 
        print("notification enabled: \(enabled)")
    }

// You can optionally subscribe a publisher to be notified when data is received from the characteristic.
let subscription2 = heartRateProxy.didUpdateValuePublisher
    .receive(on: DispatchQueue.main)
    .sink { heartRate in 
        print("heart rate is \(heartRate)")
     }

do {
    // The following will enable data notify on the Heart Rate characteristic
    // If the Heart Rate characteristic, or the service backing the Heart Rate characteristic, has not 
    // been discovered yet, a silent discovery is performed before attempting to enable data notify on the
    // characteristic.
    try await heartRateProxy.setNotify(enabled: true, timeout: .seconds(10))
    print("notify enabled on the characteristic")
} catch {
    print("failed to enable notify on the characteristic with error: \(error)")
}
```

## Providing unit tests in your codebase

By leveraging the power of **BleCentralManagerProxy**, **BlePeripheralManagerProxy** and **BlePeripheralProxy**, you can easily create mocks for your codebase, allowing you to run unit tests in a controlled environment. This is made possible because **BleCentralManagerProxy**, **BlePeripheralManagerProxy** and **BlePeripheralProxy** rely on protocols during initialization:

- **BleCentralManager**: A protocol that defines all public methods of **CBCentralManager**. **CBCentralManager** itself conforms to this protocol.
- **BlePeripheralManager**: A protocol that defines all public methods of **CBPeripheralManager**. **CBPeripheralManager** itself conforms to this protocol.
- **BlePeripheral**: A protocol that defines all public methods of **CBPeripheral**. **CBPeripheral** itself conforms to this protocol.

You can create mock versions of your central manager and peripheral(s) and supply them during the initialization of **BleCentralManagerProxy**, **BlePeripheralManagerProxy** and **BlePeripheralProxy**. This can be easily achieved by using a dependency injection (DI) container such as [Factory](https://github.com/hmlongco/Factory?tab=readme-ov-file#mocking).

- An example of a mocked central manager can be found [here](https://github.com/danielepantaleone/BlueConnect/blob/master/Tests/BlueConnectTests/CentralManager/MockBleCentralManager.swift).
- An example of a mocked peripheral manager can be found [here](https://github.com/danielepantaleone/BlueConnect/blob/master/Tests/BlueConnectTests/PeripheralManager/MockBlePeripheralManager.swift).
- An example of a mocked peripheral can be found [here](https://github.com/danielepantaleone/BlueConnect/blob/master/Tests/BlueConnectTests/Peripheral/MockBlePeripheral.swift).

## Installation

### Cocoapods

```ruby
pod 'BlueConnect', '~> 1.4.4'
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/danielepantaleone/BlueConnect.git", .upToNextMajor(from: "1.4.4"))
]
```

## Contributing

Contributions are welcome and appreciated!

If you'd like to help improve **BlueConnect**, you can contribute in the following ways:

- **Report issues**: Found a bug or unexpected behavior? Please [open an issue](https://github.com/danielepantaleone/BlueConnect/issues) with as much detail as possible. Provide also a minimal complete verifiable example to reproduce the issue.

- **Submit code**: Fixes, improvements, or new features are welcome. Fork the repository, create a feature branch, and submit a [pull request](https://github.com/danielepantaleone/BlueConnect/pulls). Please follow the existing code style and include unit tests when applicable.

- **Improve documentation**: If something in the README or code comments could be clearer, feel free to submit a pull request with improvements.

- **Suggest enhancements**: If you have an idea to improve the library, you're welcome to open an issue.

Thank you for your interest in supporting the project!

## License

```
MIT License

Copyright (c) 2025 Daniele Pantaleone

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
