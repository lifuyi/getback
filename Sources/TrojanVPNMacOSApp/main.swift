import SwiftUI
import TrojanVPNmacOS

// Import the ContentView from the TrojanVPNmacOS module
@available(macOS 13.0, *)
typealias ContentView_macOS = TrojanVPNmacOS.ContentView_macOS

@main
struct TrojanVPNMacOSApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        if #available(macOS 13.0, *) {
            window.contentView = NSHostingView(rootView: ContentView_macOS())
        } else {
            // Fallback for earlier versions
            let fallbackView = NSTextField(labelWithString: "macOS 13.0+ required")
            fallbackView.alignment = .center
            window.contentView = fallbackView
        }
        
        window.center()
        window.title = "Trojan VPN"
        window.makeKeyAndOrderFront(nil)
    }
}