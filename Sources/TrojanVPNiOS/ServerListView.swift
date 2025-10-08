import SwiftUI

struct ServerListView: View {
    @StateObject private var profileManager = ServerProfileManager.shared
    @State private var showingAddServer = false
    @State private var selectedProfile: ServerProfile?
    
    var body: some View {
        NavigationView {
            List {
                if profileManager.profiles.isEmpty {
                    VStack(spacing: 16) {
                        #if os(iOS)
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        #else
                        Image("server.rack")
                            .font(.system(size: 48))
                            .foregroundColor(Color.gray)
                        #endif
                        
                        Text("No Servers Configured")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Add your first Trojan server to get started")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #if os(iOS)
                    .listRowSeparator(.hidden)
                    #endif
                } else {
                    ForEach(profileManager.profiles) { profile in
                        ServerRowView(profile: profile)
                            .onTapGesture {
                                selectProfile(profile)
                            }
                    }
                    .onDelete(perform: deleteProfiles)
                }
            }
            .navigationTitle("Servers")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddServer = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if !profileManager.profiles.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingAddServer) {
                AddServerView()
            }
        }
    }
    
    private func selectProfile(_ profile: ServerProfile) {
        profileManager.setDefaultProfile(profile)
        // You can add haptic feedback or other UI feedback here
    }
    
    private func deleteProfiles(offsets: IndexSet) {
        for index in offsets {
            let profile = profileManager.profiles[index]
            profileManager.deleteProfile(profile)
        }
    }
}

struct ServerRowView: View {
    let profile: ServerProfile
    @StateObject private var profileManager = ServerProfileManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    
                    if profile.isDefault {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    if profile.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                Text(profile.serverAddress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Port: \(profile.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastConnected = profile.lastConnected {
                        Spacer()
                        Text("Last: \(lastConnected.timeAgoDisplay())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack {
                Button(action: { profileManager.toggleFavorite(profile) }) {
                    Image(systemName: profile.isFavorite ? "star.fill" : "star")
                        .foregroundColor(profile.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(.plain)
                
                ConnectionStatusIndicator(profile: profile)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConnectionStatusIndicator: View {
    let profile: ServerProfile
    @StateObject private var vpnManager = TrojanVPNManager.shared
    
    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 12, height: 12)
    }
    
    private var indicatorColor: Color {
        if vpnManager.currentProfile?.id == profile.id {
            return vpnManager.isConnected ? .green : (vpnManager.isConnecting ? .orange : .red)
        }
        return .gray
    }
}

struct AddServerView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var profileManager = ServerProfileManager.shared
    
    @State private var name = ""
    @State private var serverAddress = ""
    @State private var port = "443"
    @State private var password = ""
    @State private var sni = ""
    @State private var makeDefault = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Information")) {
                    TextField("Server Name", text: $name)
                    TextField("Server Address", text: $serverAddress)
                        #if os(iOS)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        #endif
                    
                    TextField("Port", text: $port)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                
                Section(header: Text("Authentication")) {
                    SecureField("Password", text: $password)
                }
                
                Section(header: Text("Advanced Settings")) {
                    TextField("SNI (Optional)", text: $sni)
                        #if os(iOS)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        #endif
                    
                    Toggle("Make Default Server", isOn: $makeDefault)
                }
            }
            .navigationTitle("Add Server")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveServer()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") {
                    showingAlert = false
                }
            } message: {
                Text(alertMessage)
            }
            #endif
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        Int(port) != nil
    }
    
    private func saveServer() {
        guard let portInt = Int(port) else {
            alertMessage = "Invalid port number"
            showingAlert = true
            return
        }
        
        let profile = ServerProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            serverAddress: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            port: portInt,
            password: password,
            sni: sni.isEmpty ? nil : sni.trimmingCharacters(in: .whitespacesAndNewlines),
            isDefault: makeDefault
        )
        
        profileManager.addProfile(profile)
        
        if makeDefault {
            profileManager.setDefaultProfile(profile)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    ServerListView()
}