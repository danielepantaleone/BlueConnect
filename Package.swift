// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BlueConnect",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(name: "BlueConnect", targets: ["BlueConnect"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.57.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.2"),
    ],
    targets: [
        .target(
            name: "BlueConnect",
            dependencies: [],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")
            ]
        ),
        .testTarget(
            name: "BlueConnectTests",
            dependencies: [
                "BlueConnect"
            ]
        ),
    ]
)
