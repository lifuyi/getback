// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrojanVPN",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "TrojanVPN",
            targets: ["TrojanVPN"]
        ),
    ],
    dependencies: [
        // Add SwiftNIO for advanced networking if needed
        // .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "TrojanVPN",
            dependencies: []
        ),
        .testTarget(
            name: "TrojanVPNTests",
            dependencies: ["TrojanVPN"]
        ),
    ]
)