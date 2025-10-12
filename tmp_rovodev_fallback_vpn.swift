#!/usr/bin/env swift

import Foundation
import NetworkExtension

// Fallback VPN solution using system configuration
print("🔧 Creating fallback VPN configuration...")
print("Since Network Extension requires proper app signing and installation,")
print("let's create a working VPN configuration using system methods.")

func createSystemVPN() {
    let manager = NEVPNManager.shared()
    
    manager.loadFromPreferences { error in
        if let error = error {
            print("Load error: \(error)")
        }
        
        // Create IKEv2 configuration (works without Network Extension)
        let ikev2 = NEVPNProtocolIKEv2()
        ikev2.serverAddress = "chinida.space"
        ikev2.remoteIdentifier = "chinida.space" 
        ikev2.localIdentifier = "TrojanVPN-Client"
        
        // Use certificate authentication
        ikev2.authenticationMethod = .certificate
        ikev2.useExtendedAuthentication = false
        
        // For testing, we'll use shared secret
        ikev2.authenticationMethod = .sharedSecret
        
        // Create shared secret reference
        let password = "fuyilee"
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "TrojanVPN-Fallback",
            kSecAttrAccount as String: "shared-secret",
            kSecValueData as String: passwordData,
            kSecReturnPersistentRef as String: true
        ]
        
        // Delete existing, add new
        SecItemDelete(query as CFDictionary)
        
        var result: AnyObject?
        let status = SecItemAdd(query as CFDictionary, &result)
        
        if status == errSecSuccess, let ref = result as? Data {
            ikev2.sharedSecretReference = ref
        }
        
        manager.protocolConfiguration = ikev2
        manager.localizedDescription = "TrojanVPN (Fallback)"
        manager.isEnabled = true
        
        manager.saveToPreferences { error in
            if let error = error {
                print("❌ Save failed: \(error)")
                print("Permission denied - need to grant VPN permissions")
            } else {
                print("✅ Fallback VPN configuration created!")
                print("You can now connect through the TrojanVPN app")
            }
        }
    }
    
    // Keep running
    RunLoop.main.run()
}

createSystemVPN()