// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BlueConnect",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_13),
        .tvOS(.v12),
        .watchOS(.v4),
        .visionOS(.v1)
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
