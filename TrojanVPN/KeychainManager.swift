import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.yourcompany.trojanvpn"
    
    private init() {}
    
    func save(_ data: Data, for key: String) -> Bool {
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
    
    func load(for key: String) -> Data? {
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
    
    func delete(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Convenience methods for VPN configuration
    
    func saveVPNConfig(_ config: VPNConfiguration) -> Bool {
        guard let data = try? JSONEncoder().encode(config) else { return false }
        return save(data, for: "vpn_config")
    }
    
    func loadVPNConfig() -> VPNConfiguration? {
        guard let data = load(for: "vpn_config"),
              let config = try? JSONDecoder().decode(VPNConfiguration.self, from: data) else {
            return nil
        }
        return config
    }
    
    func savePassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        return save(data, for: "trojan_password")
    }
    
    func loadPassword() -> String? {
        guard let data = load(for: "trojan_password"),
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }
}

struct VPNConfiguration: Codable {
    let serverAddress: String
    let port: Int
    let sni: String?
    let created: Date
    
    init(serverAddress: String, port: Int, sni: String?) {
        self.serverAddress = serverAddress
        self.port = port
        self.sni = sni
        self.created = Date()
    }
}