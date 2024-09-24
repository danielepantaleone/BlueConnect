# BlueConnect

BlueConnect is a Swift framework built on top of CoreBluetooth, designed to simplify interaction with Bluetooth Low Energy (BLE) peripherals. 
By wrapping Core Bluetooth functionalities, BlueConnect provides a modern approach to BLE communication. 
It leverages asynchronous programming models, allowing you to interact with peripherals using either traditional callbacks or Swift concurrency with async/await. 

Additionally, BlueConnect supports event notifications through Combine publishers, offering a more streamlined and reactive way to handle BLE events. 
By leveraging Swift protocols, BlueConnect also facilitates unit testing, making it easier to build testable libraries and apps that interact with BLE peripherals. 
This combination of asynchronous communication, event-driven architecture, and testability ensures a highly flexible and modern BLE development experience.

## Table of contents

* [Feature highlights](#feature-highlights)
* [Usage](#usage)
    * [Scanning for peripherals](#scanning-for-peripherals)
    * [Connecting to a peripheral](#connecting-to-a-peripheral)
* [Installation](#installation)
    * [Cocoapods](#cocoapods)
    * [Swift package manager](#swift-package-manager)
* [Contributing](#contributing)
* [License](#license)

## Feature Highlights

- Supports both iOS and macOS.
- Fully covered by unit tests.
- Replaces the delegate-based interface of `CBCentralManager` and `CBPeripheral` with closures and Swift concurrency (async/await).
- Delivers event notifications via Combine publishers for both `CBCentralManager` and `CBPeripheral`.
- Includes connection timeout handling for `CBPeripheral`.
- Includes characteristic operations timeout handling for `CBPeripheral` (discovery, read, write, set notify).
- Provides direct interaction with `CBPeripheral` characteristics with no need to manage `CBPeripheral` raw data.
- Provides an optional cache policy for `CBPeripheral` data retrieval, ideal for scenarios where characteristic data remains static over time.
- Provides automatic service/characteristic discovery when characteristic operations are requested (read, write, set notify),
- Facilitates unit testing by supporting BLE central and peripheral mocks, enabling easier testing for libraries and apps that interact with BLE peripherals.

## Usage

BlueConnect delegates its functionality to two proxies:

- `BleCentralManagerProxy`: A wrapper around `CBCentralManager`, responsible for connecting, disconnecting, and scanning for peripherals. 
It publishes events using both asynchronous methods (via callbacks or Swift concurrency) and Combine publishers.
- `BlePeripheralProxy`: A wrapper around `CBPeripheral` that handles communication with BLE peripherals and manages data transmission. 
Like the central manager proxy, it publishes events through asynchronous methods and Combine publishers.

Since communication with BLE peripherals requires encoding and decoding raw data, BlueConnect simplifies this interaction by offering 
various proxy protocols that wrap around `BlePeripheralProxy`. You can create custom proxies by conforming to these protocols,
enabling you to perform operations like reading, writing, and enabling notifications on BLE peripheral characteristics:

- `BleCharacteristicProxy`: The base proxy for discovering characteristics.
- `BleCharacteristicReadProxy`: A proxy for reading data from a characteristic.
- `BleCharacteristicWriteProxy`: A proxy for writing data to a characteristic.
- `BleCharacteristicWriteWithoutResponseProxy`: A proxy for writing data to a characteristic without awaiting a response.
- `BleCharacteristicNotifyProxy`: A proxy for enabling notifications on a characteristic.

### Scanning for peripherals

You can start scanning for BLE peripherals by calling `scanForPeripherals` on the `BleCentralManagerProxy`. 
This method allows you to provide BLE scan options, which are passed directly to the underlying `CBCentralManager`. 
You can also specify an optional timeout (defaulting to 60 seconds if not provided). 
The method returns a publisher that you can use to listen for discovered BLE peripherals, along with completion or failure events.

```swift
import BlueConnect
import Combine
import CoreBluetooth

var subscriptions: Set<AnyCancellable> = []
let centralManager = CBCentralManager()
let centralManagerProxy = BleCentralManagerProxy(centralManager: centralManager)
centralManagerProxy.scanForPeripherals(timeout: .seconds(30))
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
        receiveValue: { record in 
            // This is called multiple times for every discovered peripheral.
            print("peripheral with identifier '\(record.peripheral.identifier)' was discovered")
        }
    )
    .store(in: &subscriptions)
```

### Connecting to a peripheral

To connect to a BLE peripheral, use the `connect` method on the `BleCentralManagerProxy`. 
You can provide connection options that will be forwarded to the underlying `CBCentralManager`. 
Additionally, you have the option to specify a timeout (defaulting to no timeout if not provided).
The establishment of the connection will be notified through the Combine publisher, allowing you 
to react to the connection status.

```swift
import BlueConnect
import Combine
import CoreBluetooth

var subscriptions: Set<AnyCancellable> = []
let centralManager = CBCentralManager()
let centralManagerProxy = BleCentralManagerProxy(centralManager: centralManager)

do {

    // You can optionally subscribe a publisher to be notified when a connection is established.
    centralManagerProxy.didConnectPublisher
        .receive(on: DispatchQueue.main)
        .sink { peripheral in 
            print("peripheral with identifier '\(peripheral.identifier)' connected")
        }
        .store(in: &subscriptions)

    // The following will try to establish a connection to a BLE peripheral for at most 60 seconds.
    // If the connection cannot be stablished withing the specified amount of time, the connection 
    // attempt is dropped and an notified by raising an appropriate error. If the connection is not 
    // established then nothing is advertised on the combine publisher.
    try await centralManagerProxy.connect(
        peripheral: peripheral,
        options: nil,
        timeout: .seconds(60))

    print("peripheral with identifier '\(peripheral.identifier)' connected")

} catch {
    print("peripheral connection failed with error: \(error)")
}
```

## Installation

### Cocoapods

```ruby
pod 'BlueConnect', '~> 1.0.0'
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/danielepantaleone/BlueConnect.git", .upToNextMajor(from: "1.0.0"))
]
```

## Contributing

If you like this project, you can contribute by:

- Submitting a bug report via an [issue](https://github.com/danielepantaleone/BlueConnect/issues)
- Contributing code through a [pull request](https://github.com/danielepantaleone/BlueConnect/pulls)

## License

```
MIT License

Copyright (c) 2024 Daniele Pantaleone

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
