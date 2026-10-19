// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EmptyGameWindow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EmptyGameWindow", targets: ["EmptyGameWindow"])
    ],
    targets: [
        .executableTarget(
            name: "EmptyGameWindow",
            path: "Sources/EmptyGameWindow"
        )
    ]
)
