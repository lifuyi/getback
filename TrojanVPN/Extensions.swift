import Foundation
import SwiftUI
import NetworkExtension

// MARK: - Data Extensions
extension Data {
    func hexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if let byte = UInt8(bytes, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        
        self = data
    }
    
    func toIPv4String() -> String? {
        guard count == 4 else { return nil }
        return "\(self[0]).\(self[1]).\(self[2]).\(self[3])"
    }
    
    func toIPv6String() -> String? {
        guard count == 16 else { return nil }
        var components: [String] = []
        for i in stride(from: 0, to: 16, by: 2) {
            let value = UInt16(self[i]) << 8 | UInt16(self[i + 1])
            components.append(String(format: "%x", value))
        }
        return components.joined(separator: ":")
    }
}

// MARK: - String Extensions
extension String {
    func isValidIPAddress() -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        
        return withCString { cstring in
            inet_pton(AF_INET, cstring, &sin.sin_addr) == 1 ||
            inet_pton(AF_INET6, cstring, &sin6.sin6_addr) == 1
        }
    }
    
    func isValidDomain() -> Bool {
        let domainRegex = "^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)*((?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?))$"
        let predicate = NSPredicate(format: "SELF MATCHES[c] %@", domainRegex)
        return predicate.evaluate(with: self.lowercased())
    }
    
    func sha256() -> String {
        let data = self.data(using: .utf8) ?? Data()
        var hash = [UInt8](repeating: 0, count: 32) // SHA256 produces 32 bytes
        
        data.withUnsafeBytes { bytes in
            let _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let successGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warningOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let errorRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    
    static let backgroundGray = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let cardBackground = Color(red: 1.0, green: 1.0, blue: 1.0)
}

// MARK: - NEVPNStatus Extensions
extension NEVPNStatus {
    var displayString: String {
        switch self {
        case .invalid:
            return "Invalid"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reconnecting..."
        case .disconnecting:
            return "Disconnecting..."
        @unknown default:
            return "Unknown"
        }
    }
    
    var isActive: Bool {
        return self == .connected || self == .connecting || self == .reasserting
    }
}

// MARK: - View Extensions
extension View {
    func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Custom Shapes
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    #if os(iOS)
    var corners: UIRectCorner = .allCorners
    #endif

    func path(in rect: CGRect) -> Path {
        #if os(iOS)
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
        #else
        return Path(roundedRect: rect, cornerRadius: radius)
        #endif
    }
}

// MARK: - UserDefaults Extensions
extension UserDefaults {
    func setSecure<T: Codable>(_ object: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        KeychainManager.shared.save(data, for: key)
    }
    
    func getSecure<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = KeychainManager.shared.load(for: key),
              let object = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return object
    }
}

// MARK: - Date Extensions
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Int Extensions
extension Int64 {
    func formattedByteCount() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: self)
    }
}

// MARK: - TimeInterval Extensions
extension TimeInterval {
    func formattedDuration() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Import for C functions
#if os(iOS)
import UIKit
#endif

import CommonCrypto
import Foundation