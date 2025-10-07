import Foundation
import Network
#if os(iOS)
import NetworkExtension
#endif

public class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published public var isConnected = false
    @Published public var connectionType: NWInterface.InterfaceType = .other
    @Published public var isExpensive = false
    @Published public var isConstrained = false
    
    private var autoReconnectEnabled = true
    private weak var vpnManager: TrojanVPNManager?
    
    private init() {
        startMonitoring()
    }
    
    public func setVPNManager(_ manager: TrojanVPNManager) {
        self.vpnManager = manager
    }
    
    public func enableAutoReconnect(_ enabled: Bool) {
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
                "connectionType": String(describing: connectionType),
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