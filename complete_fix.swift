#!/usr/bin/env swift

import Foundation
import NetworkExtension

print("🔧 Fixing VPN Connection Issues...")

// Function to save VPN configuration to Keychain
func saveVPNConfig() {
    let configDict: [String: Any] = [
        "serverAddress": "chinida.space",
        "port": 443,
        "password": "fuyilee",
        "sni": "chinida.space"
    ]
    
    // Save to Keychain using the same method as the app
    let service = "com.yourcompany.trojanvpn"
    let key = "vpn_config"
    
    guard let data = try? JSONSerialization.data(withJSONObject: configDict, options: []) else {
        print("❌ Failed to serialize configuration")
        return
    }
    
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]
    
    // Delete any existing item
    SecItemDelete(query as CFDictionary)
    
    // Add the new item
    let status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecSuccess {
        print("✅ VPN configuration saved to Keychain")
    } else {
        print("❌ Failed to save VPN configuration to Keychain: \(status)")
    }
    
    // Also save the password separately
    let password = "fuyilee"
    guard let passwordData = password.data(using: .utf8) else {
        print("❌ Failed to serialize password")
        return
    }
    
    let passwordQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: "trojan_password",
        kSecValueData as String: passwordData
    ]
    
    // Delete any existing password
    SecItemDelete(passwordQuery as CFDictionary)
    
    // Add the new password
    let passwordStatus = SecItemAdd(passwordQuery as CFDictionary, nil)
    if passwordStatus == errSecSuccess {
        print("✅ Password saved to Keychain")
    } else {
        print("❌ Failed to save password to Keychain: \(passwordStatus)")
    }
}

// Function to set up the VPN manager with proper configuration
func setupVPNManager() {
    print("🔧 Setting up VPN Manager...")
    
    let manager = NEVPNManager.shared()
    
    // Load existing preferences
    manager.loadFromPreferences { error in
        if let error = error {
            print("❌ Failed to load VPN preferences: \(error)")
            return
        }
        
        // Clear any existing broken configuration
        manager.protocolConfiguration = nil
        manager.localizedDescription = nil
        manager.isEnabled = false
        
        // Save the cleared configuration
        manager.saveToPreferences { error in
            if let error = error {
                print("❌ Failed to clear existing configuration: \(error)")
                return
            }
            
            print("✅ Cleared existing VPN configuration")
            
            // Now set up the proper configuration
            setupProperVPNConfiguration(manager: manager)
        }
    }
}

func setupProperVPNConfiguration(manager: NEVPNManager) {
    print("🔧 Setting up proper VPN configuration...")
    
    // Create a NETunnelProviderProtocol configuration
    // This is what the extension expects
    let providerProtocol = NETunnelProviderProtocol()
    providerProtocol.providerBundleIdentifier = "com.trojanvpn.TrojanVPNExtension"
    providerProtocol.serverAddress = "chinida.space"
    
    // Configure the provider with the server details
    providerProtocol.providerConfiguration = [
        "serverAddress": "chinida.space",
        "port": 443,
        "password": "fuyilee",
        "sni": "chinida.space"
    ]
    
    manager.protocolConfiguration = providerProtocol
    manager.localizedDescription = "TrojanVPN - Chinida Space Server"
    manager.isEnabled = true
    
    // Save the configuration
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
        } else {
            print("✅ VPN configuration saved successfully!")
            print("\n🔧 To test the connection:")
            print("1. Open the TrojanVPN app")
            print("2. Click 'Connect'")
            print("3. If prompted, allow the VPN connection in System Preferences")
        }
    }
}

// Main execution
saveVPNConfig()
setupVPNManager()

print("\n✅ Fix process completed!")
print("Please restart the TrojanVPN app and try connecting again.")