#!/usr/bin/env swift

import Foundation
import Security

print("🔍 Verifying VPN configuration in Keychain...")

// Function to load VPN configuration from Keychain
func loadVPNConfig() -> [String: Any]? {
    let service = "com.yourcompany.trojanvpn"
    let key = "vpn_config"
    
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    if status == errSecSuccess, let data = result as? Data {
        do {
            let config = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return config
        } catch {
            print("❌ Failed to deserialize configuration: \(error)")
            return nil
        }
    } else {
        print("❌ Failed to load VPN configuration from Keychain: \(status)")
        return nil
    }
}

// Function to load password from Keychain
func loadPassword() -> String? {
    let service = "com.yourcompany.trojanvpn"
    let key = "trojan_password"
    
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    if status == errSecSuccess, let data = result as? Data,
       let password = String(data: data, encoding: .utf8) {
        return password
    } else {
        print("❌ Failed to load password from Keychain: \(status)")
        return nil
    }
}

// Main verification
print("1. Checking VPN configuration...")
if let config = loadVPNConfig() {
    print("✅ VPN configuration found in Keychain:")
    print("   Server Address: \(config["serverAddress"] ?? "N/A")")
    print("   Port: \(config["port"] ?? "N/A")")
    print("   SNI: \(config["sni"] ?? "N/A")")
} else {
    print("❌ No VPN configuration found in Keychain")
}

print("\n2. Checking password...")
if let password = loadPassword() {
    print("✅ Password found in Keychain: \(password)")
} else {
    print("❌ No password found in Keychain")
}

print("\n✅ Verification completed!")