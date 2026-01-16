// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MediaHub",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MediaHub",
            targets: ["MediaHub"]),
        .executable(
            name: "mediahub",
            targets: ["MediaHubCLI"]),
        .executable(
            name: "MediaHubUI",
            targets: ["MediaHubUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "MediaHub",
            dependencies: []),
        .executableTarget(
            name: "MediaHubCLI",
            dependencies: [
                "MediaHub",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .executableTarget(
            name: "MediaHubUI",
            dependencies: [
                "MediaHub",
            ],
            resources: [.process("Assets.xcassets")]),
        .testTarget(
            name: "MediaHubTests",
            dependencies: [
                "MediaHub",
                "MediaHubCLI"
            ]),
    ]
)
