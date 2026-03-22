// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhisperRecorder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "WhisperRecorder",
            targets: ["WhisperRecorder"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "WhisperRecorder",
            dependencies: [
                "HotKey",
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/WhisperRecorder"
        )
    ]
)