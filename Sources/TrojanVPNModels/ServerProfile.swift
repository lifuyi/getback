import Foundation

// MARK: - ServerProfile Model
/// Pure data model for VPN server configuration
/// This model contains only data and basic data manipulation methods
/// No business logic or external dependencies
public struct ServerProfile: Codable, Identifiable, Hashable {
    public var id = UUID()
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
    
    /// Updates the last connected timestamp
    public mutating func updateLastConnected() {
        lastConnected = Date()
    }
    
    /// Creates a copy of the profile with updated last connected time
    public func withUpdatedConnection() -> ServerProfile {
        var updated = self
        updated.updateLastConnected()
        return updated
    }
    
    /// Creates a copy of the profile with toggled favorite status
    public func withToggledFavorite() -> ServerProfile {
        var updated = self
        updated.isFavorite.toggle()
        return updated
    }
    
    /// Creates a copy of the profile with updated default status
    public func withDefaultStatus(_ isDefault: Bool) -> ServerProfile {
        var updated = self
        updated.isDefault = isDefault
        return updated
    }
    
    /// Creates an export-safe version without sensitive data
    public func forExport() -> ServerProfile {
        return ServerProfile(
            name: name,
            serverAddress: serverAddress,
            port: port,
            password: "", // Don't export passwords for security
            sni: sni,
            isDefault: isDefault
        )
    }
}