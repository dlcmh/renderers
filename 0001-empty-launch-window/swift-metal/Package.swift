// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MetalLaunchWindow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MetalLaunchWindow", targets: ["MetalLaunchWindow"])
    ],
    targets: [
        .executableTarget(
            name: "MetalLaunchWindow",
            path: "Sources/MetalLaunchWindow"
        )
    ]
)
