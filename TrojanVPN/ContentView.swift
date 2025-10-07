import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var vpnManager = TrojanVPNManager.shared
    @State private var serverAddress = ""
    @State private var port = "443"
    @State private var password = ""
    @State private var sni = "www.example.com"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    TextField("Server Address", text: $serverAddress)
                        .textContentType(.URL)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    
                    SecureField("Password", text: $password)
                    
                    TextField("SNI (Server Name Indication)", text: $sni)
                        .textContentType(.URL)
                }
                
                Section(header: Text("Connection")) {
                    HStack {
                        Image(systemName: vpnManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(vpnManager.isConnected ? .green : .red)
                        
                        Text(vpnManager.connectionStatus)
                        
                        Spacer()
                    }
                    
                    Button(action: toggleConnection) {
                        HStack {
                            Spacer()
                            Text(vpnManager.isConnected ? "Disconnect" : "Connect")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .disabled(vpnManager.isConnecting)
                }
                
                if vpnManager.isConnected {
                    Section(header: Text("Statistics")) {
                        HStack {
                            Text("Upload:")
                            Spacer()
                            Text(formatBytes(vpnManager.bytesUploaded))
                        }
                        
                        HStack {
                            Text("Download:")
                            Spacer()
                            Text(formatBytes(vpnManager.bytesDownloaded))
                        }
                        
                        HStack {
                            Text("Connected Time:")
                            Spacer()
                            Text(formatDuration(vpnManager.connectedDuration))
                        }
                    }
                }
            }
            .navigationTitle("Trojan VPN")
            .alert("VPN Status", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func toggleConnection() {
        if vpnManager.isConnected {
            vpnManager.disconnect { error in
                DispatchQueue.main.async {
                    if let error = error {
                        alertMessage = "Disconnect failed: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        } else {
            guard !serverAddress.isEmpty && !password.isEmpty else {
                alertMessage = "Please fill in server address and password"
                showingAlert = true
                return
            }
            
            vpnManager.setupVPN(
                serverAddress: serverAddress,
                port: Int(port) ?? 443,
                password: password,
                sni: sni.isEmpty ? nil : sni
            ) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        alertMessage = "Setup failed: \(error.localizedDescription)"
                        showingAlert = true
                        return
                    }
                    
                    vpnManager.connect { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                alertMessage = "Connection failed: \(error.localizedDescription)"
                                showingAlert = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    ContentView()
}