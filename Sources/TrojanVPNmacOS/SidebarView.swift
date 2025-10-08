import SwiftUI
import AppKit
import TrojanVPNModels
import TrojanVPNCore

@available(macOS 13.0, *)
struct SidebarView: View {
    @StateObject private var serverManager = ServerProfileManager.shared
    @Binding var selectedProfile: ServerProfile?
    @State private var showingAddServer = false
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Servers")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showingAddServer = true }) {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Server List
            List(selection: $selectedProfile) {
                if serverManager.profiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        
                        Text("No Servers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    Section("Servers") {
                        ForEach(serverManager.profiles) { profile in
                            ServerRowView_macOS(profile: profile)
                                .tag(profile)
                        }
                        .onDelete(perform: deleteProfiles)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            
            Spacer()
            
            // Footer with actions
            HStack {
                Button("Import") {
                    importServers()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Export") {
                    exportServers()
                }
                .buttonStyle(.plain)
                .disabled(serverManager.profiles.isEmpty)
            }
            .padding()
            .font(.caption)
        }
        .frame(minWidth: 200)
        .sheet(isPresented: $showingAddServer) {
            ServerConfigView()
        }
        .onAppear {
            // Select default profile if none selected
            if selectedProfile == nil {
                selectedProfile = serverManager.selectedProfile
            }
        }
    }
    
    private func deleteProfiles(offsets: IndexSet) {
        for index in offsets {
            let profile = serverManager.profiles[index]
            serverManager.deleteProfile(profile)
            
            if selectedProfile?.id == profile.id {
                selectedProfile = serverManager.profiles.first
            }
        }
    }
    
    private func importServers() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                if serverManager.importProfiles(from: data) {
                    // Success - profiles imported
                } else {
                    // Show error
                }
            } catch {
                // Show error
            }
        }
    }
    
    private func exportServers() {
        guard let data = serverManager.exportProfiles() else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "trojan-servers.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
            } catch {
                // Show error
            }
        }
    }
}

@available(macOS 13.0, *)
struct ServerRowView_macOS: View {
    let profile: ServerProfile
    @StateObject private var serverManager = ServerProfileManager.shared
    @StateObject private var vpnManager = TrojanVPNManager_macOS.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if profile.isDefault {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                    }
                    
                    if profile.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                    }
                }
                
                Text(profile.serverAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("Port: \(profile.port)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                // Connection indicator
                ConnectionStatusDot(profile: profile)
                
                // Context menu button
                Menu {
                    Button("Set as Default") {
                        serverManager.setDefaultProfile(profile)
                    }
                    
                    Button(profile.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                        serverManager.toggleFavorite(profile)
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        serverManager.deleteProfile(profile)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

@available(macOS 13.0, *)
struct ConnectionStatusDot: View {
    let profile: ServerProfile
    @StateObject private var vpnManager = TrojanVPNManager_macOS.shared
    
    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
    }
    
    private var dotColor: Color {
        if vpnManager.currentProfile?.id == profile.id {
            if vpnManager.isConnected {
                return .green
            } else if vpnManager.isConnecting {
                return .orange
            } else {
                return .red
            }
        }
        return .gray.opacity(0.3)
    }
}

@available(macOS 13.0, *)
#Preview {
    SidebarView(selectedProfile: .constant(nil))
        .frame(width: 250, height: 400)
}