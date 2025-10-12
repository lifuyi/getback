import Foundation
import NetworkExtension

public class VPNPermissionManager {
    public static let shared = VPNPermissionManager()
    
    private init() {}
    
    public enum PermissionStatus {
        case unknown
        case denied
        case granted
        case requesting
    }
    
    @Published public var permissionStatus: PermissionStatus = .unknown
    
    public func requestVPNPermission(completion: @escaping (Bool, Error?) -> Void) {
        permissionStatus = .requesting
        
        // First, try to load existing VPN configuration
        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            if error != nil {
                // If loading fails, we need to create a new configuration
                self?.createInitialVPNConfiguration(completion: completion)
            } else {
                // Configuration exists, check if it's enabled
                let manager = NEVPNManager.shared()
                if manager.isEnabled {
                    DispatchQueue.main.async {
                        self?.permissionStatus = .granted
                        completion(true, nil)
                    }
                } else {
                    // Need to enable and save
                    self?.enableVPNConfiguration(manager: manager, completion: completion)
                }
            }
        }
    }
    
    private func createInitialVPNConfiguration(completion: @escaping (Bool, Error?) -> Void) {
        let manager = NEVPNManager.shared()
        
        // Create a minimal configuration to request permission
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = "com.trojanvpn.TrojanVPNExtension"
        providerProtocol.serverAddress = "placeholder.local"
        
        // Minimal configuration
        providerProtocol.providerConfiguration = [
            "serverAddress": "placeholder.local",
            "port": 443,
            "password": "placeholder"
        ]
        
        manager.protocolConfiguration = providerProtocol
        manager.localizedDescription = "TrojanVPN"
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.permissionStatus = .denied
                    completion(false, error)
                } else {
                    self?.permissionStatus = .granted
                    completion(true, nil)
                }
            }
        }
    }
    
    private func enableVPNConfiguration(manager: NEVPNManager, completion: @escaping (Bool, Error?) -> Void) {
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.permissionStatus = .denied
                    completion(false, error)
                } else {
                    self?.permissionStatus = .granted
                    completion(true, nil)
                }
            }
        }
    }
    
    public func checkCurrentPermissionStatus() -> PermissionStatus {
        return permissionStatus
    }
    
    public func hasVPNPermission() -> Bool {
        return permissionStatus == .granted
    }
}