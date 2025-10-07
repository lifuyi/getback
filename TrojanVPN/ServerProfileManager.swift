import Foundation
import Combine

public struct ServerProfile: Codable, Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var serverAddress: String
    public var port: Int
    public var password: String
    public var sni: String?
    public var isDefault: Bool
    public var createdDate: Date
    public var lastConnected: Date?
    public var isFavorite: Bool
    
    public init(name: String, serverAddress: String, port: Int = 443, password: String, sni: String? = nil, isDefault: Bool = false) {
        self.name = name
        self.serverAddress = serverAddress
        self.port = port
        self.password = password
        self.sni = sni
        self.isDefault = isDefault
        self.createdDate = Date()
        self.isFavorite = false
    }
    
    mutating func updateLastConnected() {
        lastConnected = Date()
    }
}

public class ServerProfileManager: ObservableObject {
    public static let shared = ServerProfileManager()
    
    @Published public var profiles: [ServerProfile] = []
    @Published public var selectedProfile: ServerProfile?
    
    private let keychainKey = "server_profiles"
    
    private init() {
        loadProfiles()
    }
    
    public func addProfile(_ profile: ServerProfile) {
        var newProfile = profile
        
        // If this is the first profile, make it default
        if profiles.isEmpty {
            newProfile.isDefault = true
        }
        
        profiles.append(newProfile)
        saveProfiles()
        
        if newProfile.isDefault {
            selectedProfile = newProfile
        }
    }
    
    public func updateProfile(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        
        profiles[index] = profile
        saveProfiles()
        
        if selectedProfile?.id == profile.id {
            selectedProfile = profile
        }
    }
    
    public func deleteProfile(_ profile: ServerProfile) {
        profiles.removeAll { $0.id == profile.id }
        
        if selectedProfile?.id == profile.id {
            selectedProfile = profiles.first { $0.isDefault } ?? profiles.first
        }
        
        saveProfiles()
    }
    
    public func setDefaultProfile(_ profile: ServerProfile) {
        // Remove default from all profiles
        for i in 0..<profiles.count {
            profiles[i].isDefault = false
        }
        
        // Set new default
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].isDefault = true
            selectedProfile = profiles[index]
        }
        
        saveProfiles()
    }
    
    public func toggleFavorite(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].isFavorite.toggle()
        saveProfiles()
    }
    
    public func recordConnection(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].updateLastConnected()
        saveProfiles()
    }
    
    public func getRecentProfiles(limit: Int = 5) -> [ServerProfile] {
        return profiles
            .filter { $0.lastConnected != nil }
            .sorted { $0.lastConnected! > $1.lastConnected! }
            .prefix(limit)
            .map { $0 }
    }
    
    public func getFavoriteProfiles() -> [ServerProfile] {
        return profiles.filter { $0.isFavorite }
    }
    
    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            KeychainManager.shared.save(data, for: keychainKey)
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }
    
    private func loadProfiles() {
        guard let data = KeychainManager.shared.load(for: keychainKey) else { return }
        
        do {
            profiles = try JSONDecoder().decode([ServerProfile].self, from: data)
            selectedProfile = profiles.first { $0.isDefault } ?? profiles.first
        } catch {
            print("Failed to load profiles: \(error)")
        }
    }
    
    public func exportProfiles() -> Data? {
        // Create export-safe version without passwords
        let exportProfiles = profiles.map { profile in
            ServerProfile(
                name: profile.name,
                serverAddress: profile.serverAddress,
                port: profile.port,
                password: "", // Don't export passwords for security
                sni: profile.sni,
                isDefault: profile.isDefault
            )
        }
        
        return try? JSONEncoder().encode(exportProfiles)
    }
    
    public func importProfiles(from data: Data) -> Bool {
        do {
            let importedProfiles = try JSONDecoder().decode([ServerProfile].self, from: data)
            
            for profile in importedProfiles {
                // Check if profile already exists (by server address)
                if !profiles.contains(where: { $0.serverAddress == profile.serverAddress }) {
                    addProfile(profile)
                }
            }
            
            return true
        } catch {
            print("Failed to import profiles: \(error)")
            return false
        }
    }
}