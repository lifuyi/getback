import Foundation
import NetworkExtension
import TrojanVPNModels

public class SystemVPNInstaller {
    public static let shared = SystemVPNInstaller()
    
    private init() {}
    
    public func installSystemVPNProfile(for profile: ServerProfile, completion: @escaping (Bool, Error?) -> Void) {
        print("🔧 Installing system-level VPN profile for \(profile.name)...")
        
        // Use NEVPNManager to create system VPN configuration
        let manager = NEVPNManager.shared()
        
        manager.loadFromPreferences { error in
            if let error = error {
                print("⚠️  Load preferences warning: \(error)")
            }
            
            // Configure tunnel provider
            let providerProtocol = NETunnelProviderProtocol()
            providerProtocol.providerBundleIdentifier = "com.trojanvpn.TrojanVPNExtension"
            providerProtocol.serverAddress = profile.serverAddress
            
            // Set up Trojan configuration
            let config: [String: Any] = [
                "serverAddress": profile.serverAddress,
                "port": profile.port,
                "password": profile.password,
                "sni": profile.sni ?? profile.serverAddress,
                "protocol": "trojan"
            ]
            
            providerProtocol.providerConfiguration = config
            
            // Configure manager
            manager.protocolConfiguration = providerProtocol
            manager.localizedDescription = "TrojanVPN - \(profile.name)"
            manager.isEnabled = true
            manager.isOnDemandEnabled = false
            
            // Save to system
            manager.saveToPreferences { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to install VPN profile: \(error)")
                        completion(false, error)
                    } else {
                        print("✅ System VPN profile installed successfully!")
                        completion(true, nil)
                    }
                }
            }
        }
    }
    
    public func connectToSystemVPN(completion: @escaping (Bool, Error?) -> Void) {
        let manager = NEVPNManager.shared()
        
        manager.loadFromPreferences { error in
            if let error = error {
                completion(false, error)
                return
            }
            
            do {
                try manager.connection.startVPNTunnel()
                print("✅ System VPN connection started")
                completion(true, nil)
            } catch {
                print("❌ Failed to start VPN tunnel: \(error)")
                completion(false, error)
            }
        }
    }
    
    public func disconnectSystemVPN(completion: @escaping (Bool, Error?) -> Void) {
        let manager = NEVPNManager.shared()
        
        manager.loadFromPreferences { error in
            if let error = error {
                completion(false, error)
                return
            }
            
            manager.connection.stopVPNTunnel()
            print("✅ System VPN disconnected")
            completion(true, nil)
        }
    }
}