Release Notes
=============

Released Aug 16, 2025

## 1.5.0

- Provide swift task cancellation support [#6](https://github.com/danielepantaleone/BlueConnect/pull/6)
- Removed asynchronous isNotifying signature from BLE peripheral proxy [a5cace9](https://github.com/danielepantaleone/BlueConnect/commit/a5cace9d58020766bb234fcc2de0ff22d8566249)

## 1.4.6

Released Jun 10, 2025

- Detach RSSI notify timer if the peripheral is not connected anymore [77fd081](https://github.com/danielepantaleone/BlueConnect/commit/77fd08198f2d07b5a56bd9301e4159757343debb)
- Provide notification state check support in characteristic proxy [0da6606](https://github.com/danielepantaleone/BlueConnect/commit/0da6606502f44257f175f221d2eb3c3bb21bfb69)
- Provide notification state check support in peripheral proxy [0a9305e](https://github.com/danielepantaleone/BlueConnect/commit/0a9305e02782d7e5a2cb5e490b4f33a232c45518)
- Provide isRSSINotifying property to peripheral proxy [b08dca0](https://github.com/danielepantaleone/BlueConnect/commit/b08dca04ebb20c98a909901aba4b2db03b382329)

## 1.4.5

Released May 20, 2025

- Fix not calling connection callbacks when connection is manually canceled [5053834](https://github.com/danielepantaleone/BlueConnect/commit/5053834901dbcf43cc266387b417a5e9aaed1640)

## 1.4.4

Released May 19, 2025

- Minor improvements to connection canceled handler [e8bdc85](https://github.com/danielepantaleone/BlueConnect/commit/e8bdc85c21b5b8d2f987b50af5f415c27a200d4c)

## 1.4.3

Released May 19, 2025

- Provide dedicated error to manual connection canceling [49facd5](https://github.com/danielepantaleone/BlueConnect/commit/49facd5421910e06f8dd4c092edff6f978988fe3)

## 1.4.2

Released May 08, 2025

- Fix disconnecting peripheral not triggering connection failed publisher if link was not established [a8417cf](https://github.com/danielepantaleone/BlueConnect/commit/a8417cf94edfcca5669bb83edaf670270a1663d7)

## 1.4.1

Released April 18, 2025

- Fix RSSI unavailability detection [c6d5c1a](https://github.com/danielepantaleone/BlueConnect/commit/c6d5c1a490dcaf0bc3206f839983d904bbfb680d)

## 1.4.0

Released April 16, 2025

- Added missing sendable conformance to library proxies [91b3a3b](https://github.com/danielepantaleone/BlueConnect/commit/91b3a3b7df55469ff2b3c99e36f22446aa6cdd20)
- Added support for RSSI signal strength notification [0a89664](https://github.com/danielepantaleone/BlueConnect/commit/0a89664d3678123c6ecab5229e4822526fe6fa22)
- Fix central manager proxy not stopping BLE scan when manually requested [a0d453b](https://github.com/danielepantaleone/BlueConnect/commit/a0d453bdee2582a98d795c16e31019d5614fa5ac)
- Fix missing public accessibility to central manager proxy methods [e6b6980](https://github.com/danielepantaleone/BlueConnect/commit/e6b698072e51c7cc052819ba1c41db368a8ff22a)
- Implement peripheral scan using async throwing stream [ff32606](https://github.com/danielepantaleone/BlueConnect/commit/ff326066e50b1038061cb5e34a51eaee5cc214e6)
- Make use of integer type to deal with RSSI [6149272](https://github.com/danielepantaleone/BlueConnect/commit/6149272080b53ef5e2ea57aaa3b288b676511ebb)

## 1.3.5

Released April 7, 2025

- Removed swiftlint dependency [0377e63](https://github.com/danielepantaleone/BlueConnect/commit/0377e63009031384cc016398316d4aa4eb9d0238)

## 1.3.4

Released April 3, 2025

- Fix data race in central manager proxy [52b7ed8](https://github.com/danielepantaleone/BlueConnect/commit/52b7ed8242f9a4dfe1cb1027df1995688fd3003e)
- Make use of global serial queue instead of concurrent one [0055f18](https://github.com/danielepantaleone/BlueConnect/commit/0055f186a57a2b477306d5639e75eadc82368ba7)

## 1.3.3

Released April 1, 2025

- Removed custom recursive lock implementation in favour of Foundation's one [fb032f0](https://github.com/danielepantaleone/BlueConnect/commit/fb032f064187156e35264dd2ce27f8e49b38067a)

## 1.3.2

Released March 18, 2025

- Fix possible data race when requesting data from BLE peripheral [2a13288](https://github.com/danielepantaleone/BlueConnect/commit/2a132882be926171ca553e39153d00573ff58b3b)
- Prefer immutable properties over lazily initialized ones [b6d15c4](https://github.com/danielepantaleone/BlueConnect/commit/b6d15c4b41fec68f3f59e274811ee8a934a241f4)

## 1.3.1

Released January 20, 2025

- Fix race condition where a peripheral connection is timed out even if the peripheral is connected [dd99877](https://github.com/danielepantaleone/BlueConnect/commit/dd998773ac35d2716aafd7c0dac81feb272097b3)

**Full Changelog**: [1.3.0...1.3.1](https://github.com/danielepantaleone/BlueConnect/compare/1.3.0...1.3.1)

## 1.3.0

Released November 18, 2024

- Added missing properties to central manager proxy [0553ec4](https://github.com/danielepantaleone/BlueConnect/commit/0553ec455ab714567e690091ee3563e9a9fa3472)
- Added support for peripheral manager [11d69f9](https://github.com/danielepantaleone/BlueConnect/commit/11d69f9fa24c13918ac078bd55f472a09e8b6434) using peripheral manager proxy [8906b43](https://github.com/danielepantaleone/BlueConnect/commit/8906b4363af58c8d064b9f771610591c08b5ef71)

**Full Changelog**: [1.2.1...1.3.0](https://github.com/danielepantaleone/BlueConnect/compare/1.2.1...1.3.0)

## 1.2.1

Released November 08, 2024

- Fix build using Swift 5.9 [68629bf](https://github.com/danielepantaleone/BlueConnect/commit/68629bf9b1163d5d858d6e764fe8d613ab7abd80)

**Full Changelog**: [1.2.0...1.2.1](https://github.com/danielepantaleone/BlueConnect/compare/1.2.0...1.2.1)

## 1.2.0

Released November 06, 2024

- [#4](https://github.com/danielepantaleone/BlueConnect/pull/4) Added registry based subscription to avoid swift continuation misuse
- [#5](https://github.com/danielepantaleone/BlueConnect/pull/5) Added `retrieveConnectedPeripherals` and `retrievePeripherals` methods to central manager proxy
- Added support for RSSI read in peripheral proxy [538e3d8](https://github.com/danielepantaleone/BlueConnect/commit/538e3d81a835678c9b2a8aedb4e46e1c8f4599eb)
- Expose `isScanning` property in central manager proxy [7953223](https://github.com/danielepantaleone/BlueConnect/commit/795322376aea9159e0e29c234d04b57ae11f7133)
- Expose `maximumWriteValueLength` in peripheral proxy and characteristic proxy [faea889](https://github.com/danielepantaleone/BlueConnect/commit/faea889c64c90eda3077e8ffbdc61cb2dca39830)

**Full Changelog**: [1.1.0...1.2.0](https://github.com/danielepantaleone/BlueConnect/compare/1.1.0...1.2.0)

## 1.1.0

Released October 26, 2024

- [#1](https://github.com/danielepantaleone/BlueConnect/pull/1) Added compatibility with Swift 6 strict concurrency
- [#2](https://github.com/danielepantaleone/BlueConnect/pull/2) Added `waitUntilReady` function to central manager proxy

**Full Changelog**: [1.0.0...1.1.0](https://github.com/danielepantaleone/BlueConnect/compare/1.0.0...1.1.0)

## 1.0.0

Released October 19, 2024
