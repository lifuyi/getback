import Foundation
import Network
import NetworkExtension

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType = .other
    @Published var isExpensive = false
    @Published var isConstrained = false
    
    private var autoReconnectEnabled = true
    private weak var vpnManager: TrojanVPNManager?
    
    private init() {
        startMonitoring()
    }
    
    func setVPNManager(_ manager: TrojanVPNManager) {
        self.vpnManager = manager
    }
    
    func enableAutoReconnect(_ enabled: Bool) {
        autoReconnectEnabled = enabled
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateNetworkStatus(_ path: NWPath) {
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
        } else {
            connectionType = .other
        }
        
        // Handle network changes
        if wasConnected != isConnected {
            handleNetworkChange(wasConnected: wasConnected)
        }
        
        NotificationCenter.default.post(
            name: Notification.Name("NetworkStatusChanged"),
            object: nil,
            userInfo: [
                "isConnected": isConnected,
                "connectionType": connectionType.rawValue,
                "isExpensive": isExpensive,
                "isConstrained": isConstrained
            ]
        )
    }
    
    private func handleNetworkChange(wasConnected: Bool) {
        guard let vpnManager = vpnManager else { return }
        
        if !wasConnected && isConnected {
            // Network became available
            if autoReconnectEnabled && !vpnManager.isConnected && vpnManager.shouldAutoReconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    vpnManager.reconnect()
                }
            }
        } else if wasConnected && !isConnected {
            // Network lost
            print("Network connection lost")
        }
    }
    
    deinit {
        monitor.cancel()
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