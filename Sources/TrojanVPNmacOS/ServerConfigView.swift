import SwiftUI
import TrojanVPNModels
import TrojanVPNCore

@available(macOS 13.0, *)
struct ServerConfigView: View {
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
    
    // Add focus state to maintain input focus
    @FocusState private var focusedField: FocusField?
    
    enum FocusField {
        case name, address, port, password, sni
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Add New Server")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            // Simple form fields
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Name")
                        .font(.headline)
                    TextField("Enter server name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .address }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Address")
                        .font(.headline)
                    TextField("server.example.com", text: $serverAddress)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)
                        .focused($focusedField, equals: .address)
                        .onSubmit { focusedField = .port }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Port")
                            .font(.headline)
                        TextField("443", text: $port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100, height: 30)
                            .focused($focusedField, equals: .port)
                            .onSubmit { focusedField = .password }
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)
                        .focused($focusedField, equals: .password)
                        .onSubmit { focusedField = .sni }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("SNI (Optional)")
                        .font(.headline)
                    TextField("server.example.com", text: $sni)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 30)
                        .focused($focusedField, equals: .sni)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Set as default server", isOn: $makeDefault)
                    Toggle("Add to favorites", isOn: $makeFavorite)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Bottom buttons
            HStack(spacing: 16) {
                Button("Test Connection") {
                    testConnection()
                }
                .disabled(!isFormValid)
                
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)
                
                Button("Add Server") {
                    addServer()
                }
                .disabled(!isFormValid)
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
        .frame(width: 500, height: 500)
        .alert("Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // Set focus to first field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .name
            }
        }
        .onTapGesture {
            // Prevent losing focus when tapping elsewhere in the view
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        Int(port) != nil &&
        (Int(port) ?? 0) > 0 &&
        (Int(port) ?? 0) <= 65535
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
        
        closeWindow()
    }
    
    private func closeWindow() {
        // Find and close the current window
        if let window = NSApp.keyWindow {
            window.close()
        }
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
struct SimpleInputTest: View {
    @Environment(\.dismiss) private var dismiss
    @State private var testText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Input Test")
                .font(.title)
            
            TextField("Type here to test", text: $testText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300, height: 40)
            
            Text("Current text: '\(testText)'")
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("OK") {
                    print("Text entered: \(testText)")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 400, height: 200)
    }
}

@available(macOS 13.0, *)
#Preview {
    ServerConfigView()
}