import Foundation
import Network
import Combine
import AppKit
import TrojanVPNCore

class NetworkMonitor_macOS: ObservableObject {
    static let shared = NetworkMonitor_macOS()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor_macOS")
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType = .other
    @Published var isExpensive = false
    @Published var isConstrained = false
    @Published var isEnabled = true
    
    private var autoReconnectEnabled = true
    private weak var vpnManager: TrojanVPNManager_macOS?
    
    private init() {
        startMonitoring()
    }
    
    func setVPNManager(_ manager: TrojanVPNManager_macOS) {
        self.vpnManager = manager
    }
    
    func enableAutoReconnect(_ enabled: Bool) {
        autoReconnectEnabled = enabled
    }
    
    private func startMonitoring() {
        guard isEnabled else { return }
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateNetworkStatus(_ path: Network.NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else if path.usesInterfaceType(.loopback) {
            connectionType = .loopback
        } else {
            connectionType = .other
        }
        
        // Handle network changes
        if wasConnected != isConnected {
            handleNetworkChange(wasConnected: wasConnected)
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name("NetworkStatusChanged"),
            object: nil,
            userInfo: [
                "isConnected": isConnected,
                "connectionType": connectionType.displayName,
                "isExpensive": isExpensive,
                "isConstrained": isConstrained
            ]
        )
    }
    
    private func handleNetworkChange(wasConnected: Bool) {
        guard let vpnManager = vpnManager else { return }
        
        if !wasConnected && isConnected {
            // Network became available
            print("Network connection restored: \(connectionType.displayName)")
            
            if autoReconnectEnabled && !vpnManager.isConnected && vpnManager.shouldAutoReconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    vpnManager.reconnect()
                }
            }
        } else if wasConnected && !isConnected {
            // Network lost
            print("Network connection lost")
            
            // Send notification
            let notification = NSUserNotification()
            notification.title = "Network Disconnected"
            notification.informativeText = "Internet connection has been lost"
            NSUserNotificationCenter.default.deliver(notification)
        } else if wasConnected && isConnected {
            // Network type changed
            print("Network type changed to: \(connectionType.displayName)")
        }
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Network Interface Information
    func getNetworkInterfaces() -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        
        // Get available network interfaces (simplified)
        let types: [NWInterface.InterfaceType] = [.wifi, .wiredEthernet, .cellular, .loopback]
        
        for type in types {
            let interface = NetworkInterface(
                name: type.displayName,
                type: type,
                isActive: connectionType == type && isConnected
            )
            interfaces.append(interface)
        }
        
        return interfaces
    }
    
    // MARK: - Connection Quality
    func getConnectionQuality() -> ConnectionQuality {
        if !isConnected {
            return .none
        }
        
        if isConstrained {
            return .poor
        }
        
        if isExpensive {
            return .limited
        }
        
        switch connectionType {
        case .wiredEthernet:
            return .excellent
        case .wifi:
            return .good
        case .cellular:
            return isExpensive ? .limited : .fair
        default:
            return .fair
        }
    }
}

// MARK: - Supporting Types
struct NetworkInterface {
    let name: String
    let type: NWInterface.InterfaceType
    let isActive: Bool
}

enum ConnectionQuality: String, CaseIterable {
    case none = "No Connection"
    case poor = "Poor"
    case limited = "Limited"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"
    
    var color: NSColor {
        switch self {
        case .none:
            return .systemRed
        case .poor:
            return .systemOrange
        case .limited:
            return .systemYellow
        case .fair:
            return .systemBlue
        case .good:
            return .systemGreen
        case .excellent:
            return .systemGreen
        }
    }
}

extension NWInterface.InterfaceType {
    var displayName: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Network Testing
extension NetworkMonitor_macOS {
    func performConnectivityTest(completion: @escaping (Bool, TimeInterval) -> Void) {
        let startTime = Date()
        
        guard let url = URL(string: "https://www.google.com") else {
            completion(false, 0)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let duration = Date().timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                if error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(true, duration)
                } else {
                    completion(false, duration)
                }
            }
        }.resume()
    }
    
    func getPublicIPAddress(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.ipify.org") else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let data = data, error == nil {
                    completion(String(data: data, encoding: .utf8))
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
}