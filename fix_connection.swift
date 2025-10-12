#!/usr/bin/env swift

import Foundation
import NetworkExtension
import TrojanVPNModels
import TrojanVPNCore

print("🔧 Fixing VPN Connection Issues...")
print("This script will properly configure the VPN for testing.")

// First, ensure we have a valid server profile
let serverProfile = ServerProfile(
    name: "Chinida Space Server",
    serverAddress: "chinida.space",
    port: 443,
    password: "fuyilee",
    sni: "chinida.space",
    isDefault: true
)

print("\n1. Adding server profile...")
ServerProfileManager.shared.addProfile(serverProfile)
print("✅ Server profile added")

// Request VPN permissions
print("\n2. Requesting VPN permissions...")
let semaphore = DispatchSemaphore(value: 0)

VPNPermissionManager.shared.requestVPNPermission { granted, error in
    if granted {
        print("✅ VPN permission granted")
    } else {
        print("❌ VPN permission denied: \(error?.localizedDescription ?? "Unknown error")")
        print("   Please go to System Preferences > Profiles & Device Management")
        print("   and approve the VPN configuration profile.")
    }
    semaphore.signal()
}

semaphore.wait()

print("\n3. Setting up proper VPN configuration...")

// Load the VPN manager
NEVPNManager.shared().loadFromPreferences { error in
    if let error = error {
        print("❌ Failed to load VPN preferences: \(error)")
        exit(1)
    }
    
    let manager = NEVPNManager.shared()
    
    // Create a proper NETunnelProviderProtocol configuration
    // This is what the extension expects
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
    
    manager.saveToPreferences { error in
        if let error = error {
            print("❌ Failed to save VPN configuration: \(error)")
            if error.localizedDescription.contains("permission") {
                print("   This is a permission issue. Please:")
                print("   1. Go to System Preferences > Network")
                print("   2. Click the lock icon and enter your password")
                print("   3. Find TrojanVPN in the list and click '-' to remove it")
                print("   4. Restart the app and try connecting again")
            }
            exit(1)
        } else {
            print("✅ VPN configuration saved successfully!")
            print("\n🔧 To test the connection:")
            print("1. Open the TrojanVPN app")
            print("2. Click 'Connect'")
            print("3. If prompted, allow the VPN connection in System Preferences")
            print("\nIf you still get 'permission denied', please:")
            print("1. Go to System Preferences > Network")
            print("2. Select TrojanVPN")
            print("3. Click 'Advanced'")
            print("4. Check 'Show VPN status in menu bar'")
            print("5. Try connecting again")
        }
    }
}

// Keep the script running
RunLoop.main.run()