import NetworkExtension
import Foundation
import Combine

class TrojanVPNManager: ObservableObject {
    static let shared = TrojanVPNManager()
    
    private var manager: NEVPNManager?
    private var statusObserver: NSObjectProtocol?
    private var connectTime: Date?
    private var timer: Timer?
    private var reconnectTimer: Timer?
    
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionStatus = "Disconnected"
    @Published var bytesUploaded: Int64 = 0
    @Published var bytesDownloaded: Int64 = 0
    @Published var connectedDuration: TimeInterval = 0
    @Published var currentProfile: ServerProfile?
    
    // Advanced features
    var shouldAutoReconnect = true
    var maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    private var lastDisconnectReason: NEProviderStopReason?
    
    private init() {
        loadManager()
        setupStatusObserver()
        setupNetworkMonitoring()
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        timer?.invalidate()
    }
    
    private func loadManager() {
        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load VPN preferences: \(error)")
                } else {
                    self?.manager = NEVPNManager.shared()
                    self?.updateConnectionStatus()
                }
            }
        }
    }
    
    private func setupStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateConnectionStatus()
        }
    }
    
    private func setupNetworkMonitoring() {
        NetworkMonitor.shared.setVPNManager(self)
        
        // Listen for network changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NetworkStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNetworkChange(notification)
        }
    }
    
    private func handleNetworkChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isConnected = userInfo["isConnected"] as? Bool else { return }
        
        if isConnected && !self.isConnected && shouldAutoReconnect && currentProfile != nil {
            // Network restored and we should reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.reconnect()
            }
        }
    }
    
    private func updateConnectionStatus() {
        guard let manager = manager else { return }
        
        let status = manager.connection.status
        
        switch status {
        case .invalid:
            connectionStatus = "Invalid"
            isConnected = false
            isConnecting = false
        case .disconnected:
            connectionStatus = "Disconnected"
            isConnected = false
            isConnecting = false
            stopTimer()
            KillSwitchManager.shared.handleVPNStatusChange(status)
            
            // Handle automatic reconnection
            if shouldAutoReconnect && reconnectAttempts < maxReconnectAttempts {
                scheduleReconnect()
            }
        case .connecting:
            connectionStatus = "Connecting..."
            isConnected = false
            isConnecting = true
        case .connected:
            connectionStatus = "Connected"
            isConnected = true
            isConnecting = false
            reconnectAttempts = 0 // Reset on successful connection
            startTimer()
            KillSwitchManager.shared.handleVPNStatusChange(status)
            
            // Record successful connection
            if let profile = currentProfile {
                ServerProfileManager.shared.recordConnection(profile)
            }
        case .reasserting:
            connectionStatus = "Reasserting..."
            isConnected = true
            isConnecting = false
        case .disconnecting:
            connectionStatus = "Disconnecting..."
            isConnected = false
            isConnecting = true
        @unknown default:
            connectionStatus = "Unknown"
            isConnected = false
            isConnecting = false
        }
    }
    
    private func startTimer() {
        connectTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        connectTime = nil
        connectedDuration = 0
        bytesUploaded = 0
        bytesDownloaded = 0
    }
    
    private func updateStats() {
        if let connectTime = connectTime {
            connectedDuration = Date().timeIntervalSince(connectTime)
        }
        
        // In a real implementation, you would get these stats from the packet tunnel
        // For now, we'll simulate some traffic
        if isConnected {
            bytesUploaded += Int64.random(in: 100...1000)
            bytesDownloaded += Int64.random(in: 500...2000)
        }
    }
    
    // MARK: - Auto Reconnection Methods
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectAttempts += 1
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0) // Exponential backoff, max 60s
        
        connectionStatus = "Reconnecting in \(Int(delay))s..."
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.reconnect()
        }
    }
    
    func reconnect() {
        guard let profile = currentProfile else { return }
        
        connect(with: profile) { [weak self] error in
            if let error = error {
                print("Reconnection failed: \(error)")
                self?.scheduleReconnect()
            }
        }
    }
    
    func cancelReconnection() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        shouldAutoReconnect = false
        reconnectAttempts = 0
    }
    
    // MARK: - Enhanced VPN Setup
    func setupVPN(serverAddress: String, port: Int, password: String, sni: String? = nil, completion: @escaping (Error?) -> Void) {
        let profile = ServerProfile(
            name: "Quick Connect",
            serverAddress: serverAddress,
            port: port,
            password: password,
            sni: sni
        )
        
        setupVPN(with: profile, completion: completion)
    }
    
    func setupVPN(with profile: ServerProfile, completion: @escaping (Error?) -> Void) {
        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            let manager = NEVPNManager.shared()
            
            // Configure packet tunnel
            let providerProtocol = NETunnelProviderProtocol()
            providerProtocol.providerBundleIdentifier = "com.yourcompany.trojanvpn.extension"
            providerProtocol.serverAddress = serverAddress
            
            // Store configuration in providerConfiguration
            var config: [String: Any] = [
                "serverAddress": profile.serverAddress,
                "port": profile.port,
                "password": profile.password,
                "enableUDP": true, // Enable UDP support for Trojan-Go
                "enableWebSocket": false, // Can be enabled for better obfuscation
                "mux": true, // Enable connection multiplexing
                "fastOpen": true // Enable TCP Fast Open
            ]
            
            if let sni = profile.sni {
                config["sni"] = sni
            }
            
            providerProtocol.providerConfiguration = config
            
            manager.protocolConfiguration = providerProtocol
            manager.localizedDescription = "Trojan VPN - \(profile.name)"
            manager.isEnabled = true
            manager.isOnDemandEnabled = false // Can be enabled for auto-connect
            
            manager.saveToPreferences { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(error)
                    } else {
                        self?.manager = manager
                        self?.currentProfile = profile
                        completion(nil)
                    }
                }
            }
        }
    }
    
    func connect(with profile: ServerProfile, completion: @escaping (Error?) -> Void) {
        setupVPN(with: profile) { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            self?.connect(completion: completion)
        }
    }
    
    func connect(completion: @escaping (Error?) -> Void) {
        guard let manager = manager else {
            completion(NSError(domain: "TrojanVPN", code: -1, userInfo: [NSLocalizedDescriptionKey: "VPN not configured"]))
            return
        }
        
        do {
            try manager.connection.startVPNTunnel()
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    func disconnect(completion: @escaping (Error?) -> Void) {
        guard let manager = manager else {
            completion(NSError(domain: "TrojanVPN", code: -1, userInfo: [NSLocalizedDescriptionKey: "VPN not configured"]))
            return
        }
        
        manager.connection.stopVPNTunnel()
        completion(nil)
    }
}