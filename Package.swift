// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TapDetection",
    platforms: [
        .watchOS(.v9),
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TapDetection",
            targets: ["TapDetection"]
        ),
    ],
    targets: [
        .target(
            name: "TapDetection"
        ),
        .testTarget(
            name: "TapDetectionTests",
            dependencies: ["TapDetection"]
        ),
    ]
)
