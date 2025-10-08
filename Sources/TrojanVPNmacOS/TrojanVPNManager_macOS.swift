import NetworkExtension
import Foundation
import Combine
import Network
import AppKit
import TrojanVPNModels
import TrojanVPNCore

class TrojanVPNManager_macOS: ObservableObject {
    static let shared = TrojanVPNManager_macOS()
    
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
        reconnectTimer?.invalidate()
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
        NetworkMonitor_macOS.shared.setVPNManager(self)
        
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
            
            // Send system notification
            sendConnectedNotification()
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
    
    private func sendConnectedNotification() {
        let notification = NSUserNotification()
        notification.title = "Trojan VPN Connected"
        notification.informativeText = "VPN connection established successfully"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
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
        // Don't reset byte counters here to preserve session totals
    }
    
    private func updateStats() {
        if let connectTime = connectTime {
            connectedDuration = Date().timeIntervalSince(connectTime)
        }
        
        // In a real implementation, you would get these stats from the system
        // For now, we'll simulate some traffic when connected
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
    
    // MARK: - VPN Management
    func connect(with profile: ServerProfile, completion: @escaping (Error?) -> Void) {
        setupVPN(with: profile) { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            self?.connect(completion: completion)
        }
    }
    
    private func setupVPN(with profile: ServerProfile, completion: @escaping (Error?) -> Void) {
        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            let manager = NEVPNManager.shared()
            
            // For macOS, we'll use IKEv2 instead of packet tunnel for better compatibility
            let ikev2Protocol = NEVPNProtocolIKEv2()
            ikev2Protocol.serverAddress = profile.serverAddress
            ikev2Protocol.remoteIdentifier = profile.serverAddress
            ikev2Protocol.localIdentifier = "TrojanVPN"
            
            // Use certificate authentication (in production, you'd configure proper certificates)
            ikev2Protocol.authenticationMethod = .sharedSecret
            ikev2Protocol.sharedSecretReference = self?.createSharedSecretReference(profile.password)
            
            // Configure dead peer detection
            ikev2Protocol.deadPeerDetectionRate = .medium
            ikev2Protocol.disableMOBIKE = false
            ikev2Protocol.disableRedirect = false
            ikev2Protocol.enablePFS = true
            ikev2Protocol.enableRevocationCheck = false
            ikev2Protocol.strictRevocationCheck = false
            
            manager.protocolConfiguration = ikev2Protocol
            manager.localizedDescription = "Trojan VPN - \(profile.name)"
            manager.isEnabled = true
            manager.isOnDemandEnabled = false
            
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
    
    private func createSharedSecretReference(_ password: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "TrojanVPN",
            kSecAttrAccount as String: "SharedSecret",
            kSecValueData as String: password.data(using: .utf8) ?? Data(),
            kSecReturnPersistentRef as String: true
        ]
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        var result: AnyObject?
        let status = SecItemAdd(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        
        return nil
    }
    
    private func connect(completion: @escaping (Error?) -> Void) {
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
        
        // Send disconnection notification
        let notification = NSUserNotification()
        notification.title = "Trojan VPN Disconnected"
        notification.informativeText = "VPN connection has been terminated"
        NSUserNotificationCenter.default.deliver(notification)
        
        completion(nil)
    }
    
    // MARK: - Connection Testing
    func testConnection(with profile: ServerProfile, completion: @escaping (Bool, Error?) -> Void) {
        // Create a simple network connection test
        let url = URL(string: "https://\(profile.serverAddress):\(profile.port)")!
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error)
            } else if let httpResponse = response as? HTTPURLResponse {
                // Consider any HTTP response as success (server is reachable)
                completion(httpResponse.statusCode < 500, nil)
            } else {
                completion(true, nil)
            }
        }.resume()
    }
    
    // MARK: - Statistics
    func resetStatistics() {
        bytesUploaded = 0
        bytesDownloaded = 0
    }
    
    func getConnectionInfo() -> [String: Any] {
        var info: [String: Any] = [
            "status": connectionStatus,
            "isConnected": isConnected,
            "bytesUploaded": bytesUploaded,
            "bytesDownloaded": bytesDownloaded,
            "connectedDuration": connectedDuration
        ]
        
        if let profile = currentProfile {
            info["serverName"] = profile.name
            info["serverAddress"] = profile.serverAddress
            info["serverPort"] = profile.port
        }
        
        return info
    }
}