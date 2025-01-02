// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "trmnl-tides",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(
            url: "https://github.com/hummingbird-project/hummingbird",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.0.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Server",
            dependencies: [
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
                .target(name: "App"),
            ]
        ),
        .target(
            name: "App",
            dependencies: [
                .product(
                    name: "Hummingbird",
                    package: "hummingbird"
                ),
                .product(
                    name: "HummingbirdFoundation",
                    package: "hummingbird"
                ),
            ],
            swiftSettings: [
                .unsafeFlags(
                    ["-cross-module-optimization"],
                    .when(configuration: .release)
                ),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .product(
                    name: "HummingbirdXCT",
                    package: "hummingbird"
                ),
                .target(name: "App"),
            ]
        ),    ]
)
