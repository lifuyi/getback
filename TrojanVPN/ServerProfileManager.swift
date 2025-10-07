import Foundation
import Combine

struct ServerProfile: Codable, Identifiable, Hashable {
    let id = UUID()
    var name: String
    var serverAddress: String
    var port: Int
    var password: String
    var sni: String?
    var isDefault: Bool
    var createdDate: Date
    var lastConnected: Date?
    var isFavorite: Bool
    
    init(name: String, serverAddress: String, port: Int = 443, password: String, sni: String? = nil, isDefault: Bool = false) {
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

class ServerProfileManager: ObservableObject {
    static let shared = ServerProfileManager()
    
    @Published var profiles: [ServerProfile] = []
    @Published var selectedProfile: ServerProfile?
    
    private let keychainKey = "server_profiles"
    
    private init() {
        loadProfiles()
    }
    
    func addProfile(_ profile: ServerProfile) {
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
    
    func updateProfile(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        
        profiles[index] = profile
        saveProfiles()
        
        if selectedProfile?.id == profile.id {
            selectedProfile = profile
        }
    }
    
    func deleteProfile(_ profile: ServerProfile) {
        profiles.removeAll { $0.id == profile.id }
        
        if selectedProfile?.id == profile.id {
            selectedProfile = profiles.first { $0.isDefault } ?? profiles.first
        }
        
        saveProfiles()
    }
    
    func setDefaultProfile(_ profile: ServerProfile) {
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
    
    func toggleFavorite(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].isFavorite.toggle()
        saveProfiles()
    }
    
    func recordConnection(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].updateLastConnected()
        saveProfiles()
    }
    
    func getRecentProfiles(limit: Int = 5) -> [ServerProfile] {
        return profiles
            .filter { $0.lastConnected != nil }
            .sorted { $0.lastConnected! > $1.lastConnected! }
            .prefix(limit)
            .map { $0 }
    }
    
    func getFavoriteProfiles() -> [ServerProfile] {
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
    
    func exportProfiles() -> Data? {
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
    
    func importProfiles(from data: Data) -> Bool {
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