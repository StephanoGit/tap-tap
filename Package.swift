// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TapTap",
    platforms: [
        .iOS(.v15),
        .watchOS(.v8),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "TapTap",
            targets: ["TapTap"]
        ),
    ],
    targets: [
        .target(
            name: "TapTap"
        ),
        .testTarget(
            name: "TapTapTests",
            dependencies: ["TapTap"]
        ),
    ]
)
