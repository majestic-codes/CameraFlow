// swift-tools-version: 6.2.3
import PackageDescription

let package = Package(
    name: "CameraFlow",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CameraFlow", targets: ["CameraFlow"])
    ],
    targets: [
        .target(
            name: "CameraFlow",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "CameraFlowTests", dependencies: ["CameraFlow"])
    ]
)
