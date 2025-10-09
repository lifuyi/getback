#!/usr/bin/env swift

import Foundation

// Server configuration
let serverName = "Default Server"
let serverAddress = "chinida.space"
let port = 443
let password = "fuyilee"

// Create a simple JSON representation of the server profile
let profileData: [String: Any] = [
    "id": UUID().uuidString,
    "name": serverName,
    "serverAddress": serverAddress,
    "port": port,
    "password": password,
    "sni": NSNull(),
    "isDefault": true,
    "createdDate": ISO8601DateFormatter().string(from: Date()),
    "lastConnected": NSNull(),
    "isFavorite": false
]

// Convert to JSON
do {
    let jsonData = try JSONSerialization.data(withJSONObject: profileData, options: .prettyPrinted)
    
    // Save to a temporary file
    let tempFile = "/tmp/default_server.json"
    try jsonData.write(to: URL(fileURLWithPath: tempFile))
    
    print("✅ Default server profile created and saved to \(tempFile)")
    print("Server: \(serverAddress):\(port)")
    print("Name: \(serverName)")
    print("Password: \(password)")
    print("Is Default: true")
    
    // Now we need to add this to the app's keychain storage
    // For now, we'll print instructions for the user
    print("\n⚠️ To complete setup, you need to:")
    print("1. Open the Trojan VPN app")
    print("2. Click the '+' button to add a new server")
    print("3. Enter these details:")
    print("   - Name: \(serverName)")
    print("   - Server Address: \(serverAddress)")
    print("   - Port: \(port)")
    print("   - Password: \(password)")
    print("   - Check 'Set as default server'")
    print("4. Click 'Add Server'")
    
} catch {
    print("❌ Failed to create server profile: \(error)")
    exit(1)
}