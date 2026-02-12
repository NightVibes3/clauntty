// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RtachClient",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RtachClient",
            targets: ["RtachClient"]
        ),
    ],
    targets: [
        .target(
            name: "RtachClient",
            dependencies: []
        ),
        .testTarget(
            name: "RtachClientTests",
            dependencies: ["RtachClient"]
        ),
    ]
)
