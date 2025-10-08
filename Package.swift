// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrojanVPN",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        // Models library - Foundation data models (most reusable)
        .library(
            name: "TrojanVPNModels",
            targets: ["TrojanVPNModels"]
        ),
        // Core library with Controllers (shared between iOS and macOS)
        .library(
            name: "TrojanVPNCore",
            targets: ["TrojanVPNCore"]
        ),
        // Network Extension library (shared between iOS and macOS)
        .library(
            name: "TrojanVPNExtension", 
            targets: ["TrojanVPNExtension"]
        ),
        // iOS specific Views
        .library(
            name: "TrojanVPNiOS",
            targets: ["TrojanVPNiOS"]
        ),
        // macOS specific Views
        .library(
            name: "TrojanVPNmacOS",
            targets: ["TrojanVPNmacOS"]
        ),
        .executable(
            name: "TrojanVPNDemo",
            targets: ["TrojanVPNDemo"]
        ),
    ],
    dependencies: [
        // No external dependencies for now to keep it simple
    ],
    targets: [
        // MARK: - Models (Data Layer) - Most foundational, no dependencies
        .target(
            name: "TrojanVPNModels",
            dependencies: [],
            path: "Sources/TrojanVPNModels"
        ),
        
        // MARK: - Core (Controllers + Utilities) - Depends on Models
        .target(
            name: "TrojanVPNCore",
            dependencies: ["TrojanVPNModels"],
            path: "Sources/TrojanVPNCore",
            sources: [
                "Controllers/",
                "Utilities/"
            ]
        ),
        
        // MARK: - Network Extension - Shared between iOS and macOS
        .target(
            name: "TrojanVPNExtension",
            dependencies: ["TrojanVPNModels", "TrojanVPNCore"],
            path: "Sources/TrojanVPNExtension"
        ),
        
        // MARK: - iOS Views
        .target(
            name: "TrojanVPNiOS",
            dependencies: ["TrojanVPNModels", "TrojanVPNCore"],
            path: "Sources/TrojanVPNiOS"
        ),
        
        // MARK: - macOS Views  
        .target(
            name: "TrojanVPNmacOS",
            dependencies: ["TrojanVPNModels", "TrojanVPNCore"],
            path: "Sources/TrojanVPNmacOS"
        ),
        
        // MARK: - Demo App
        .executableTarget(
            name: "TrojanVPNDemo",
            dependencies: ["TrojanVPNModels", "TrojanVPNCore", "TrojanVPNiOS"],
            path: "Sources/TrojanVPNDemo"
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "TrojanVPNTests",
            dependencies: ["TrojanVPNModels", "TrojanVPNCore"],
            path: "Tests/TrojanVPNTests"
        ),
    ]
)