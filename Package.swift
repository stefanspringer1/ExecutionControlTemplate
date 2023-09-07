// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DistributedActorsTest",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", Version("1.0.1")...Version("1.0.1")),
        .package(url: "https://github.com/stefanspringer1/SwiftUtilities", from: "0.0.208"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "NonDistributed",
            path: "Sources/NonDistributed"
        ),
        .target(
            name: "Framework",
            path: "Sources/Distributed/Framework"
        ),
        .executableTarget(
            name: "DistributedMaster",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Utilities", package: "SwiftUtilities"),
                "Framework",
            ],
            path: "Sources/Distributed/Master"
        ),
        .executableTarget(
            name: "DistributedWorker",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Framework",
            ],
            path: "Sources/Distributed/Worker"
        ),
    ]
)
