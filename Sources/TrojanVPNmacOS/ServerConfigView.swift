import SwiftUI
import TrojanVPNCore

@available(macOS 13.0, *)
struct ServerConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverManager = ServerProfileManager.shared
    
    @State private var name = ""
    @State private var serverAddress = ""
    @State private var port = "443"
    @State private var password = ""
    @State private var sni = ""
    @State private var makeDefault = false
    @State private var makeFavorite = false
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Add New Server")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Configure your Trojan server connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section("Server Information") {
                    TextField("Server Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Server Address", text: $serverAddress)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    TextField("Port", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                }
                
                Section("Authentication") {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Advanced Settings") {
                    TextField("SNI (Optional)", text: $sni)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Set as default server", isOn: $makeDefault)
                        Toggle("Add to favorites", isOn: $makeFavorite)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Spacer()
            
            // Footer
            HStack {
                Button("Test Connection") {
                    testConnection()
                }
                .disabled(!isFormValid)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Add Server") {
                    addServer()
                }
                .disabled(!isFormValid)
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        Int(port) != nil
    }
    
    private func testConnection() {
        guard let portInt = Int(port) else {
            alertMessage = "Invalid port number"
            showingAlert = true
            return
        }
        
        // Create a temporary profile for testing
        let testProfile = ServerProfile(
            name: "Test Connection",
            serverAddress: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            port: portInt,
            password: password,
            sni: sni.isEmpty ? nil : sni.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Test the connection (simplified)
        TrojanVPNManager_macOS.shared.testConnection(with: testProfile) { success, error in
            DispatchQueue.main.async {
                if success {
                    alertMessage = "Connection test successful!"
                } else {
                    alertMessage = "Connection test failed: \(error?.localizedDescription ?? "Unknown error")"
                }
                showingAlert = true
            }
        }
    }
    
    private func addServer() {
        guard let portInt = Int(port) else {
            alertMessage = "Invalid port number"
            showingAlert = true
            return
        }
        
        var profile = ServerProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            serverAddress: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            port: portInt,
            password: password,
            sni: sni.isEmpty ? nil : sni.trimmingCharacters(in: .whitespacesAndNewlines),
            isDefault: makeDefault
        )
        
        profile.isFavorite = makeFavorite
        
        serverManager.addProfile(profile)
        
        if makeDefault {
            serverManager.setDefaultProfile(profile)
        }
        
        dismiss()
    }
}

@available(macOS 13.0, *)
struct SettingsView: View {
    @StateObject private var killSwitchManager = KillSwitchManager.shared
    @StateObject private var vpnManager = TrojanVPNManager_macOS.shared
    @StateObject private var networkMonitor = NetworkMonitor_macOS.shared
    
    var body: some View {
        TabView {
            // General Settings
            Form {
                Section("Connection") {
                    Toggle("Enable Kill Switch", isOn: .init(
                        get: { killSwitchManager.isEnabled },
                        set: { killSwitchManager.enableKillSwitch($0) }
                    ))
                    
                    Toggle("Auto Reconnect", isOn: .init(
                        get: { vpnManager.shouldAutoReconnect },
                        set: { vpnManager.shouldAutoReconnect = $0 }
                    ))
                    
                    Stepper("Max Reconnect Attempts: \(vpnManager.maxReconnectAttempts)", 
                           value: .init(
                               get: { vpnManager.maxReconnectAttempts },
                               set: { vpnManager.maxReconnectAttempts = $0 }
                           ),
                           in: 1...10)
                }
                
                Section("Network") {
                    Toggle("Monitor Network Changes", isOn: .init(
                        get: { networkMonitor.isEnabled },
                        set: { networkMonitor.isEnabled = $0 }
                    ))
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // Advanced Settings
            Form {
                Section("Protocol") {
                    Toggle("Enable UDP Support", isOn: .constant(true))
                        .disabled(true)
                    
                    Toggle("Connection Multiplexing", isOn: .constant(true))
                        .disabled(true)
                    
                    Toggle("TCP Fast Open", isOn: .constant(true))
                        .disabled(true)
                }
                
                Section("Security") {
                    Toggle("Certificate Validation", isOn: .constant(true))
                        .disabled(true)
                    
                    Toggle("TLS 1.3 Only", isOn: .constant(true))
                        .disabled(true)
                }
            }
            .tabItem {
                Label("Advanced", systemImage: "slider.horizontal.3")
            }
            
            // About
            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("Trojan VPN")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Secure tunneling with Trojan protocol")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Built with Swift and SwiftUI")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/lifuyi/getback")!)
                        .font(.caption2)
                }
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 500, height: 400)
    }
}

@available(macOS 13.0, *)
#Preview {
    ServerConfigView()
}