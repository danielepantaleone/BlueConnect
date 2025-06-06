// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BlueConnect",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(name: "BlueConnect", targets: ["BlueConnect"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.2"),
    ],
    targets: [
        .target(name: "BlueConnect"),
        .testTarget(
            name: "BlueConnectTests",
            dependencies: [
                "BlueConnect"
            ]
        ),
    ],
    swiftLanguageVersions: [
        .v5,
        .version("6")
    ]
)
