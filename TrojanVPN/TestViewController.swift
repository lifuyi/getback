import UIKit
import SwiftUI

// Example UIKit implementation for testing
class TestViewController: UIViewController {
    
    @IBOutlet weak var serverAddressTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var sniTextField: UITextField!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var killSwitchSwitch: UISwitch!
    @IBOutlet weak var autoReconnectSwitch: UISwitch!
    
    private let vpnManager = TrojanVPNManager.shared
    private let killSwitchManager = KillSwitchManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        loadSavedConfiguration()
    }
    
    private func setupUI() {
        title = "Trojan VPN Test"
        
        // Set default values
        serverAddressTextField.text = "your-server.com"
        portTextField.text = "443"
        sniTextField.text = "www.example.com"
        
        // Configure switches
        killSwitchSwitch.isOn = killSwitchManager.isEnabled
        autoReconnectSwitch.isOn = vpnManager.shouldAutoReconnect
        
        updateUI()
    }
    
    private func setupObservers() {
        // Observe VPN status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusChanged),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        
        // Observe network changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: Notification.Name("NetworkStatusChanged"),
            object: nil
        )
    }
    
    @objc private func vpnStatusChanged() {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    @objc private func networkStatusChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateNetworkStatus(notification)
        }
    }
    
    private func updateUI() {
        statusLabel.text = vpnManager.connectionStatus
        
        if vpnManager.isConnected {
            connectButton.setTitle("Disconnect", for: .normal)
            connectButton.backgroundColor = .systemRed
        } else if vpnManager.isConnecting {
            connectButton.setTitle("Connecting...", for: .normal)
            connectButton.backgroundColor = .systemOrange
            connectButton.isEnabled = false
        } else {
            connectButton.setTitle("Connect", for: .normal)
            connectButton.backgroundColor = .systemBlue
            connectButton.isEnabled = true
        }
    }
    
    private func updateNetworkStatus(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isConnected = userInfo["isConnected"] as? Bool,
              let connectionType = userInfo["connectionType"] as? String else { return }
        
        let networkStatus = isConnected ? "Network: \(connectionType)" : "Network: Disconnected"
        print("Network Status: \(networkStatus)")
    }
    
    @IBAction func connectButtonTapped(_ sender: UIButton) {
        if vpnManager.isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    @IBAction func killSwitchToggled(_ sender: UISwitch) {
        killSwitchManager.enableKillSwitch(sender.isOn)
    }
    
    @IBAction func autoReconnectToggled(_ sender: UISwitch) {
        vpnManager.shouldAutoReconnect = sender.isOn
        networkMonitor.enableAutoReconnect(sender.isOn)
    }
    
    private func connect() {
        guard let serverAddress = serverAddressTextField.text, !serverAddress.isEmpty,
              let portText = portTextField.text, let port = Int(portText),
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all required fields")
            return
        }
        
        let sni = sniTextField.text?.isEmpty == false ? sniTextField.text : nil
        
        vpnManager.setupVPN(
            serverAddress: serverAddress,
            port: port,
            password: password,
            sni: sni
        ) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Setup Error", message: error.localizedDescription)
                    return
                }
                
                self?.vpnManager.connect { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.showAlert(title: "Connection Error", message: error.localizedDescription)
                        } else {
                            print("Connected successfully!")
                            self?.saveConfiguration()
                        }
                    }
                }
            }
        }
    }
    
    private func disconnect() {
        vpnManager.disconnect { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Disconnect Error", message: error.localizedDescription)
                } else {
                    print("Disconnected successfully!")
                }
            }
        }
    }
    
    private func saveConfiguration() {
        let config = VPNConfiguration(
            serverAddress: serverAddressTextField.text ?? "",
            port: Int(portTextField.text ?? "443") ?? 443,
            sni: sniTextField.text?.isEmpty == false ? sniTextField.text : nil
        )
        
        KeychainManager.shared.saveVPNConfig(config)
        
        if let password = passwordTextField.text, !password.isEmpty {
            KeychainManager.shared.savePassword(password)
        }
    }
    
    private func loadSavedConfiguration() {
        if let config = KeychainManager.shared.loadVPNConfig() {
            serverAddressTextField.text = config.serverAddress
            portTextField.text = String(config.port)
            sniTextField.text = config.sni
        }
        
        if let password = KeychainManager.shared.loadPassword() {
            passwordTextField.text = password
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Advanced Testing Methods
    
    @IBAction func testConnectionSpeed(_ sender: UIButton) {
        guard vpnManager.isConnected else {
            showAlert(title: "Error", message: "Please connect to VPN first")
            return
        }
        
        // Implement speed test logic here
        performSpeedTest()
    }
    
    @IBAction func exportLogs(_ sender: UIButton) {
        exportDebugLogs()
    }
    
    private func performSpeedTest() {
        // Simple speed test implementation
        let url = URL(string: "https://httpbin.org/bytes/1048576")! // 1MB download
        let startTime = Date()
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Speed Test Failed", message: error.localizedDescription)
                } else if let data = data {
                    let mbps = (Double(data.count) * 8) / (duration * 1_000_000) // Convert to Mbps
                    self?.showAlert(title: "Speed Test Result", message: String(format: "Download Speed: %.2f Mbps", mbps))
                }
            }
        }.resume()
    }
    
    private func exportDebugLogs() {
        // Create debug information
        var debugInfo = """
        Trojan VPN Debug Information
        ===========================
        
        VPN Status: \(vpnManager.connectionStatus)
        Connected: \(vpnManager.isConnected)
        Server: \(serverAddressTextField.text ?? "N/A")
        Port: \(portTextField.text ?? "N/A")
        SNI: \(sniTextField.text ?? "N/A")
        
        Network Status: \(networkMonitor.isConnected ? "Connected" : "Disconnected")
        Connection Type: \(networkMonitor.connectionType.displayName)
        Is Expensive: \(networkMonitor.isExpensive)
        Is Constrained: \(networkMonitor.isConstrained)
        
        Kill Switch: \(killSwitchManager.isEnabled ? "Enabled" : "Disabled")
        Kill Switch Active: \(killSwitchManager.isActive ? "Yes" : "No")
        
        Auto Reconnect: \(vpnManager.shouldAutoReconnect ? "Enabled" : "Disabled")
        Reconnect Attempts: \(vpnManager.maxReconnectAttempts)
        
        Statistics:
        - Bytes Uploaded: \(vpnManager.bytesUploaded.formattedByteCount())
        - Bytes Downloaded: \(vpnManager.bytesDownloaded.formattedByteCount())
        - Connected Duration: \(vpnManager.connectedDuration.formattedDuration())
        
        Generated: \(Date())
        """
        
        // Create and present activity controller
        let activityController = UIActivityViewController(
            activityItems: [debugInfo],
            applicationActivities: nil
        )
        
        present(activityController, animated: true)
    }
}

// MARK: - SwiftUI Wrapper for Testing
struct TestViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> TestViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "TestViewController") as! TestViewController
    }
    
    func updateUIViewController(_ uiViewController: TestViewController, context: Context) {
        // No updates needed
    }
}