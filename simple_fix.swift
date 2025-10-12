#!/usr/bin/env swift

import Foundation
import NetworkExtension
import TrojanVPNModels
import TrojanVPNCore

print("🔧 Fixing VPN Connection Issues...")

// Add a default server profile
let serverProfile = ServerProfile(
    name: "Chinida Space Server",
    serverAddress: "chinida.space",
    port: 443,
    password: "fuyilee",
    sni: "chinida.space",
    isDefault: true
)

print("1. Adding server profile...")
ServerProfileManager.shared.addProfile(serverProfile)
print("✅ Server profile added")

print("2. Loading VPN manager...")
let manager = NEVPNManager.shared()

// Create a proper NETunnelProviderProtocol configuration
let providerProtocol = NETunnelProviderProtocol()
providerProtocol.providerBundleIdentifier = "com.trojanvpn.TrojanVPNExtension"
providerProtocol.serverAddress = serverProfile.serverAddress

// Configure the provider with the server details
providerProtocol.providerConfiguration = [
    "serverAddress": serverProfile.serverAddress,
    "port": serverProfile.port,
    "password": serverProfile.password,
    "sni": serverProfile.sni ?? ""
]

manager.protocolConfiguration = providerProtocol
manager.localizedDescription = "TrojanVPN - \(serverProfile.name)"
manager.isEnabled = true

print("3. Saving VPN configuration...")
do {
    try manager.saveToPreferences()
    print("✅ VPN configuration saved successfully!")
    print("\n🔧 To test the connection:")
    print("1. Open the TrojanVPN app")
    print("2. Click 'Connect'")
    print("3. If prompted, allow the VPN connection in System Preferences")
} catch {
    print("❌ Failed to save VPN configuration: \(error)")
    if error.localizedDescription.contains("permission") {
        print("   This is a permission issue. Please:")
        print("   1. Go to System Preferences > Network")
        print("   2. Click the lock icon and enter your password")
        print("   3. Find TrojanVPN in the list and click '-' to remove it")
        print("   4. Restart the app and try connecting again")
    }
}