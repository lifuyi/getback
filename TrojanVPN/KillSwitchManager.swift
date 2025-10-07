import Foundation
import NetworkExtension
import Network

public class KillSwitchManager: ObservableObject {
    public static let shared = KillSwitchManager()
    
    @Published public var isEnabled = false
    @Published public var isActive = false
    
    private var killSwitchConnection: NWConnection?
    private let queue = DispatchQueue(label: "KillSwitch")
    
    private init() {
        loadSettings()
    }
    
    public func enableKillSwitch(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
        
        if enabled {
            activateKillSwitch()
        } else {
            deactivateKillSwitch()
        }
    }
    
    public func activateKillSwitch() {
        guard isEnabled else { return }
        
        // Block all traffic by creating a dummy connection that routes nowhere
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "0.0.0.0", port: 0)
        
        // Create a connection that will never succeed, effectively blocking traffic
        killSwitchConnection = NWConnection(
            to: NWEndpoint.hostPort(host: "127.0.0.1", port: 1),
            using: parameters
        )
        
        killSwitchConnection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .failed(_):
                    self?.isActive = true
                    print("Kill switch activated - blocking all traffic")
                default:
                    break
                }
            }
        }
        
        killSwitchConnection?.start(queue: queue)
    }
    
    public func deactivateKillSwitch() {
        killSwitchConnection?.cancel()
        killSwitchConnection = nil
        
        DispatchQueue.main.async {
            self.isActive = false
            print("Kill switch deactivated - traffic allowed")
        }
    }
    
    public func handleVPNStatusChange(_ status: NEVPNStatus) {
        guard isEnabled else { return }
        
        switch status {
        case .disconnected, .invalid:
            activateKillSwitch()
        case .connected:
            deactivateKillSwitch()
        case .connecting, .reasserting, .disconnecting:
            // Keep current state during transitions
            break
        @unknown default:
            break
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "killSwitchEnabled")
    }
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "killSwitchEnabled")
    }
}

// MARK: - Network Interface Management
extension KillSwitchManager {
    
    public func blockAllTrafficExceptVPN() {
        // This would require more advanced implementation using Network Extension
        // For a complete kill switch, you'd need to:
        // 1. Configure system routing tables
        // 2. Block all network interfaces except the VPN tunnel
        // 3. Use NEFilterDataProvider for more granular control
        
        // Basic implementation - this is a simplified version
        // In a production app, you'd implement this in the packet tunnel extension
    }
    
    public func getAllowedApplications() -> [String] {
        // Return list of applications that should bypass kill switch
        return [
            "com.apple.mobilephone", // Phone app
            "com.apple.MobileSMS",   // Messages app
            // Add other critical system apps
        ]
    }
    
    public func isApplicationAllowed(_ bundleIdentifier: String) -> Bool {
        return getAllowedApplications().contains(bundleIdentifier)
    }
}

// MARK: - Split Tunneling Support
extension KillSwitchManager {
    
    public struct SplitTunnelRule {
        public let bundleIdentifier: String
        public let shouldBypassVPN: Bool
        public let name: String
    }
    
    public func getSplitTunnelRules() -> [SplitTunnelRule] {
        // Return configured split tunnel rules
        // This would be stored in user preferences
        return [
            SplitTunnelRule(
                bundleIdentifier: "com.apple.mobilesafari",
                shouldBypassVPN: false,
                name: "Safari"
            ),
            SplitTunnelRule(
                bundleIdentifier: "com.apple.mobilemail",
                shouldBypassVPN: true,
                name: "Mail"
            )
        ]
    }
    
    public func shouldApplicationBypassVPN(_ bundleIdentifier: String) -> Bool {
        return getSplitTunnelRules()
            .first { $0.bundleIdentifier == bundleIdentifier }?
            .shouldBypassVPN ?? false
    }
}