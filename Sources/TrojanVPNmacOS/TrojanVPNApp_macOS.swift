import SwiftUI

//@main
@available(macOS 13.0, *)
struct TrojanVPNApp_macOS: App {
    var body: some Scene {
        WindowGroup {
            ContentView_macOS()
        }
        .windowStyle(DefaultWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection") {
                    // Add new connection action
                }
                .keyboardShortcut("n")
            }
            
            CommandGroup(after: .toolbar) {
                Button("Connect/Disconnect") {
                    // Toggle connection action
                }
                .keyboardShortcut("c")
            }
        }
        
    }
}