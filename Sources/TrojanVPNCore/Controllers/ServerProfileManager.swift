import Foundation
import Combine
import TrojanVPNModels

// MARK: - ServerProfileManager Controller
/// Controller responsible for managing ServerProfile collections and persistence
/// This is where the business logic for profile management lives
public class ServerProfileManager: ObservableObject {
    public static let shared = ServerProfileManager()
    
    @Published public var profiles: [ServerProfile] = []
    @Published public var selectedProfile: ServerProfile?
    
    private let keychainKey = "server_profiles"
    
    private init() {
        loadProfiles()
    }
    
    // MARK: - Profile Management
    
    public func addProfile(_ profile: ServerProfile) {
        var newProfile = profile
        
        // If this is the first profile, make it default
        if profiles.isEmpty {
            newProfile = newProfile.withDefaultStatus(true)
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
        profiles = profiles.map { $0.withDefaultStatus(false) }
        
        // Set new default
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profiles[index].withDefaultStatus(true)
            selectedProfile = profiles[index]
        }
        
        saveProfiles()
    }
    
    public func toggleFavorite(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profiles[index].withToggledFavorite()
        saveProfiles()
    }
    
    public func recordConnection(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profiles[index].withUpdatedConnection()
        saveProfiles()
    }
    
    // MARK: - Profile Queries
    
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
    
    public func getDefaultProfile() -> ServerProfile? {
        return profiles.first { $0.isDefault }
    }
    
    // MARK: - Persistence
    
    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            let success = KeychainManager.shared.save(data, for: keychainKey)
            if !success {
                print("Failed to save profiles to keychain")
            }
        } catch {
            print("Failed to encode profiles: \(error)")
        }
    }
    
    private func loadProfiles() {
        guard let data = KeychainManager.shared.load(for: keychainKey) else {
            // No existing profiles, add default server
            addDefaultServer()
            return
        }
        
        do {
            profiles = try JSONDecoder().decode([ServerProfile].self, from: data)
            selectedProfile = getDefaultProfile() ?? profiles.first
            
            // If no profiles exist after loading, add default server
            if profiles.isEmpty {
                addDefaultServer()
            }
        } catch {
            print("Failed to load profiles: \(error)")
            // On error, add default server
            addDefaultServer()
        }
    }
    
    private func addDefaultServer() {
        let defaultServer = ServerProfile(
            name: "China VPN",
            serverAddress: "chinida.space",
            port: 443,
            password: "fuyilee",
            isDefault: true
        )
        
        profiles = [defaultServer]
        selectedProfile = defaultServer
        saveProfiles()
        
        print("Added default server: chinida.space:443")
    }
    
    // MARK: - Import/Export
    
    public func exportProfiles() -> Data? {
        let exportProfiles = profiles.map { $0.forExport() }
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
    
    // MARK: - Validation
    
    public func validateProfile(_ profile: ServerProfile) -> [String] {
        var errors: [String] = []
        
        if profile.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Profile name cannot be empty")
        }
        
        if profile.serverAddress.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Server address cannot be empty")
        }
        
        if profile.port < 1 || profile.port > 65535 {
            errors.append("Port must be between 1 and 65535")
        }
        
        if profile.password.isEmpty {
            errors.append("Password cannot be empty")
        }
        
        return errors
    }
    
    public func isValidProfile(_ profile: ServerProfile) -> Bool {
        return validateProfile(profile).isEmpty
    }
}