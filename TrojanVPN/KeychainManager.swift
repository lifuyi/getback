import Foundation
import Security

public class KeychainManager {
    public static let shared = KeychainManager()
    
    private let service = "com.yourcompany.trojanvpn"
    
    private init() {}
    
    public func save(_ data: Data, for key: String) -> Bool {
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
        return status == errSecSuccess
    }
    
    public func load(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        
        return nil
    }
    
    public func delete(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Convenience methods for VPN configuration
    
    public func saveVPNConfig(_ config: VPNConfiguration) -> Bool {
        guard let data = try? JSONEncoder().encode(config) else { return false }
        return save(data, for: "vpn_config")
    }
    
    public func loadVPNConfig() -> VPNConfiguration? {
        guard let data = load(for: "vpn_config"),
              let config = try? JSONDecoder().decode(VPNConfiguration.self, from: data) else {
            return nil
        }
        return config
    }
    
    public func savePassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        return save(data, for: "trojan_password")
    }
    
    public func loadPassword() -> String? {
        guard let data = load(for: "trojan_password"),
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }
}

public struct VPNConfiguration: Codable {
    public let serverAddress: String
    public let port: Int
    public let password: String
    public let sni: String?
}