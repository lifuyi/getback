import Foundation

struct Constants {
    
    // MARK: - App Configuration
    struct App {
        static let name = "Trojan VPN"
        static let version = "1.0.0"
        static let bundleIdentifier = "com.yourcompany.trojanvpn"
        static let extensionBundleIdentifier = "com.yourcompany.trojanvpn.extension"
    }
    
    // MARK: - Network Configuration
    struct Network {
        static let defaultPort = 443
        static let defaultDNS = ["8.8.8.8", "8.8.4.4"]
        static let tunnelMTU = 1500
        static let connectionTimeout: TimeInterval = 30
        static let keepAliveInterval: TimeInterval = 30
    }
    
    // MARK: - Trojan Protocol
    struct Trojan {
        static let crlf = "\r\n"
        static let connectCommand: UInt8 = 0x01
        static let udpAssociateCommand: UInt8 = 0x03
        static let ipv4AddressType: UInt8 = 0x01
        static let domainNameAddressType: UInt8 = 0x03
        static let ipv6AddressType: UInt8 = 0x04
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let animationDuration = 0.3
        static let defaultServerPort = "443"
        static let defaultSNI = "www.example.com"
    }
    
    // MARK: - Keychain Keys
    struct Keychain {
        static let vpnConfigKey = "vpn_config"
        static let passwordKey = "trojan_password"
        static let serverListKey = "server_list"
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let invalidConfiguration = "Invalid VPN configuration"
        static let connectionFailed = "Failed to establish VPN connection"
        static let permissionDenied = "VPN permission denied"
        static let serverUnreachable = "Server is unreachable"
        static let authenticationFailed = "Authentication failed"
        static let networkError = "Network error occurred"
    }
    
    // MARK: - Notification Names
    struct Notifications {
        static let vpnStatusChanged = "VPNStatusChanged"
        static let configurationUpdated = "ConfigurationUpdated"
        static let statsUpdated = "StatsUpdated"
    }
}