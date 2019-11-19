// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "FDWaveformView",
    products: [
        .library(
            name: "FDWaveformView",
            targets: ["FDWaveformView"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FDWaveformView",
            dependencies: []
        ),
        .testTarget(
            name: "FDWaveformViewTests",
            dependencies: ["FDWaveformView"]
        )
    ]
)
