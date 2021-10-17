// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "FDWaveformView",
    platforms: [.iOS(.v9)],
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
    ],
    swiftLanguageVersions: [.v5]
)
