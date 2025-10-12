#!/usr/bin/env swift

import Foundation

// Simple script to add a default server profile
print("🔧 Adding default server profile...")

let defaultProfile = """
{
    "id": "\(UUID().uuidString)",
    "name": "Chinida Space Server",
    "serverAddress": "chinida.space",
    "port": 443,
    "password": "fuyilee",
    "sni": "chinida.space",
    "isDefault": true,
    "createdDate": "\(Date())",
    "isFavorite": false
}
"""

// Save to a temporary file that the app can read
let tempFile = "/tmp/trojan_default_profile.json"
do {
    try defaultProfile.write(toFile: tempFile, atomically: true, encoding: .utf8)
    print("✅ Default server profile saved to \(tempFile)")
    print("The app should now be able to read this profile on startup.")
} catch {
    print("❌ Failed to save default profile: \(error)")
}