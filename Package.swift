// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrojanVPN",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "TrojanVPNCore",
            targets: ["TrojanVPNCore"]
        ),
        .library(
            name: "TrojanVPNExtension", 
            targets: ["TrojanVPNExtension"]
        ),
        .library(
            name: "TrojanVPN_macOS",
            targets: ["TrojanVPN_macOS"]
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
        .target(
            name: "TrojanVPNCore",
            dependencies: [],
            path: "TrojanVPN",
            sources: [
                "TrojanVPNApp.swift",
                "ContentView.swift", 
                "TrojanVPNManager.swift",
                "KeychainManager.swift",
                "Constants.swift",
                "Extensions.swift",
                "NetworkMonitor.swift",
                "ServerProfileManager.swift",
                "KillSwitchManager.swift",
                "ServerListView.swift",
                "TestViewController.swift"
            ]
        ),
        .target(
            name: "TrojanVPNExtension",
            dependencies: [],
            path: "TrojanVPNExtension", 
            sources: [
                "TrojanPacketTunnelProvider.swift",
                "TrojanConnection.swift",
                "TrojanProtocol.swift",
                "PacketParser.swift"
            ]
        ),
        .target(
            name: "TrojanVPN_macOS",
            dependencies: ["TrojanVPNCore"],
            path: "TrojanVPN_macOS",
            sources: [
                "TrojanVPNApp_macOS.swift",
                "ContentView_macOS.swift",
                "SidebarView.swift",
                "ServerConfigView.swift",
                "TrojanVPNManager_macOS.swift",
                "NetworkMonitor_macOS.swift"
            ]
        ),
        .executableTarget(
            name: "TrojanVPNDemo",
            dependencies: ["TrojanVPNCore", "TrojanVPN_macOS"],
            path: "Demo"
        ),
        .testTarget(
            name: "TrojanVPNTests",
            dependencies: ["TrojanVPNCore"]
        ),
    ]
)