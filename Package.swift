// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebNativeBridge",
    platforms: [
        .custom("macos", versionString: "12.3"),
        .custom("maccatalyst", versionString: "15.4"),
        .custom("ios", versionString: "15.4"),
        .custom("tvos", versionString: "15.4"),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WebNativeBridge",
            targets: ["WebNativeBridge"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Flight-School/AnyCodable",
            from: "0.6.0"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WebNativeBridge",
            dependencies: ["AnyCodable"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "WebNativeBridgeTests",
            dependencies: ["WebNativeBridge"]
        ),
    ]
)
