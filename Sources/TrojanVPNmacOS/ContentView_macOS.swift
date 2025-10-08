import SwiftUI
import NetworkExtension
import TrojanVPNModels
import TrojanVPNCore

@available(macOS 13.0, *)
public struct ContentView_macOS: View {
    public init() {}
    @StateObject private var vpnManager = TrojanVPNManager_macOS.shared
    @StateObject private var serverManager = ServerProfileManager.shared
    @State private var selectedProfile: ServerProfile?
    @State private var showingServerConfig = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar - Server List
            SidebarView(selectedProfile: $selectedProfile)
        } detail: {
            // Main Content
            VStack(spacing: 20) {
                // Header
                HeaderView()
                
                // Connection Status
                ConnectionStatusView()
                
                // Connection Controls
                ConnectionControlsView(
                    selectedProfile: selectedProfile,
                    showingAlert: $showingAlert,
                    alertMessage: $alertMessage
                )
                
                Spacer()
                
                // Statistics
                if vpnManager.isConnected {
                    StatisticsView()
                }
            }
            .padding()
            .frame(minWidth: 500, minHeight: 400)
        }
        .navigationTitle("Trojan VPN")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    showingServerConfig = true
                }) {
                    Image(systemName: "plus")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Button(vpnManager.isConnected ? "Disconnect" : "Connect") {
                        toggleConnection()
                    }
                    .disabled(vpnManager.isConnecting || selectedProfile == nil)
                    
                    Menu {
                        Button("Preferences...") {
                            NSApp.sendAction(Selector("showPreferencesWindow:"), to: nil, from: nil)
                        }
                        .keyboardShortcut(",")
                        
                        Divider()
                        
                        Button("About Trojan VPN") {
                            // Show about dialog
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingServerConfig) {
            ServerConfigView()
        }
        .alert("VPN Status", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
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
            guard let profile = selectedProfile else {
                alertMessage = "Please select a server profile"
                showingAlert = true
                return
            }
            
            vpnManager.connect(with: profile) { error in
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

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "shield.checkered")
                .font(.system(size: 32))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("Trojan VPN")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Secure tunneling with Trojan protocol")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

@available(macOS 13.0, *)
struct ConnectionStatusView: View {
    @StateObject private var vpnManager = TrojanVPNManager_macOS.shared
    @StateObject private var networkMonitor = NetworkMonitor_macOS.shared
    
    var body: some View {
        GroupBox("Connection Status") {
            VStack(spacing: 12) {
                HStack {
                    StatusIndicator(status: vpnManager.connectionStatus)
                    Spacer()
                    Text(vpnManager.connectionStatus)
                        .font(.headline)
                        .foregroundColor(statusColor)
                }
                
                if vpnManager.isConnected {
                    HStack {
                        Text("Connected for:")
                        Spacer()
                        Text(formatDuration(vpnManager.connectedDuration))
                            .font(.monospaced(.body)())
                    }
                }
                
                HStack {
                    Text("Network:")
                    Spacer()
                    Text(networkMonitor.connectionType.displayName)
                        .foregroundColor(networkMonitor.isConnected ? .green : .red)
                }
            }
            .padding()
        }
    }
    
    private var statusColor: Color {
        if vpnManager.isConnected {
            return .green
        } else if vpnManager.isConnecting {
            return .orange
        } else {
            return .red
        }
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

struct StatusIndicator: View {
    let status: String
    
    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(indicatorColor.opacity(0.3), lineWidth: 4)
                    .scaleEffect(isConnected ? 1.5 : 1.0)
                    .opacity(isConnected ? 0 : 1)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: isConnected)
            )
    }
    
    private var indicatorColor: Color {
        switch status.lowercased() {
        case let s where s.contains("connected") && !s.contains("disconnected"):
            return .green
        case let s where s.contains("connecting"):
            return .orange
        default:
            return .red
        }
    }
    
    private var isConnected: Bool {
        status.lowercased().contains("connected") && !status.lowercased().contains("disconnected")
    }
}

@available(macOS 13.0, *)
struct ConnectionControlsView: View {
    let selectedProfile: ServerProfile?
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    @StateObject private var killSwitchManager = KillSwitchManager.shared
    @StateObject private var vpnManager = TrojanVPNManager_macOS.shared
    
    var body: some View {
        GroupBox("Connection Settings") {
            VStack(spacing: 16) {
                if let profile = selectedProfile {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Server:")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                
                                Text("\(profile.serverAddress):\(profile.port)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if profile.isFavorite {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    Text("No server selected")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    Toggle("Enable Kill Switch", isOn: .init(
                        get: { killSwitchManager.isEnabled },
                        set: { killSwitchManager.enableKillSwitch($0) }
                    ))
                    
                    Toggle("Auto Reconnect", isOn: .init(
                        get: { vpnManager.shouldAutoReconnect },
                        set: { vpnManager.shouldAutoReconnect = $0 }
                    ))
                }
            }
            .padding()
        }
    }
}

@available(macOS 13.0, *)
struct StatisticsView: View {
    @StateObject private var vpnManager = TrojanVPNManager_macOS.shared
    
    var body: some View {
        GroupBox("Traffic Statistics") {
            HStack(spacing: 32) {
                VStack {
                    Text("Upload")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatBytes(vpnManager.bytesUploaded))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack {
                    Text("Download")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatBytes(vpnManager.bytesDownloaded))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

@available(macOS 13.0, *)
#Preview {
    ContentView_macOS()
}