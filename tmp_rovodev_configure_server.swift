import Foundation
import TrojanVPNModels
import TrojanVPNCore

// Configure the server profile with your details
let serverProfile = ServerProfile(
    name: "Chinida Space Server",
    serverAddress: "chinida.space",
    port: 443,
    password: "fuyilee", 
    sni: "chinida.space",
    isDefault: true
)

print("Creating server profile:")
print("- Name: \(serverProfile.name)")
print("- Server: \(serverProfile.serverAddress)")
print("- Port: \(serverProfile.port)")
print("- SNI: \(serverProfile.sni ?? "None")")
print("- Default: \(serverProfile.isDefault)")

// Save to ServerProfileManager
ServerProfileManager.shared.addProfile(serverProfile)
print("\n✅ Server profile added successfully!")
print("The 'Invalid' status should now change to 'Disconnected'")