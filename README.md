# Trojan VPN iOS Client

A complete iOS implementation of a Trojan protocol VPN client that disguises VPN traffic as HTTPS traffic to bypass censorship.

## Features

- **Trojan Protocol Implementation**: Full support for Trojan protocol with TLS encryption
- **Network Extension**: Packet Tunnel Provider for system-wide VPN functionality  
- **SwiftUI Interface**: Modern, intuitive user interface
- **Secure Storage**: Keychain integration for secure credential storage
- **Connection Statistics**: Real-time traffic monitoring and connection duration
- **Multiple Server Support**: Easy configuration switching between servers

## Architecture

```
Main App (TrojanVPN)
├── UI Layer (SwiftUI)
├── VPN Manager
├── Keychain Manager
└── Configuration Storage

Packet Tunnel Extension (TrojanVPNExtension)  
├── Packet Tunnel Provider
├── Trojan Connection Handler
├── Protocol Implementation
└── Packet Parser
```

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.3+
- Valid Apple Developer Account (for Network Extension entitlements)
- Physical iOS device (Network Extensions don't work in Simulator)

## Setup Instructions

### 1. Configure Bundle Identifiers

Update the bundle identifiers in the project:
- Main App: `com.yourcompany.trojanvpn`
- Extension: `com.yourcompany.trojanvpn.extension`

### 2. Enable Capabilities

In both targets, enable:
- **Network Extensions** capability
- **Keychain Sharing** capability

### 3. Configure Entitlements

Ensure both targets have the Network Extension entitlements:
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
```

### 4. Update Extension Bundle ID

In `TrojanVPNManager.swift`, update the provider bundle identifier:
```swift
providerProtocol.providerBundleIdentifier = "com.yourcompany.trojanvpn.extension"
```

## Trojan Protocol Details

### Authentication
- Uses SHA256 hash of password for authentication
- Hash is sent in hexadecimal format during handshake

### Traffic Disguise
- All traffic flows through TLS/SSL connection on port 443
- Appears as legitimate HTTPS traffic to network monitors
- Uses Server Name Indication (SNI) for additional obfuscation

### Protocol Flow
1. Establish TLS connection to server
2. Send Trojan handshake with password hash
3. Send SOCKS5-style connection request
4. Forward packets through encrypted tunnel

## Server Configuration

Your Trojan server should be configured with:
- Valid TLS certificate (Let's Encrypt recommended)
- Same password as configured in the app
- Port 443 open for HTTPS traffic
- Proper routing configuration

Example server config (trojan-go):
```json
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": ["your-password-here"],
    "ssl": {
        "cert": "/path/to/certificate.crt",
        "key": "/path/to/private.key",
        "sni": "your-domain.com"
    }
}
```

## Usage

1. **Configure Server**: Enter server address, port, password, and SNI
2. **Connect**: Tap Connect to establish VPN tunnel
3. **Monitor**: View real-time statistics and connection status
4. **Disconnect**: Tap Disconnect to stop VPN tunnel

## Security Considerations

- Passwords are stored securely in iOS Keychain
- All traffic is encrypted using TLS 1.3
- Certificate validation is enforced
- No logs are stored locally

## Testing

### Prerequisites
- Physical iOS device (required for Network Extensions)
- Valid provisioning profile with Network Extension entitlements
- Trojan server running and accessible

### Test Steps
1. Build and install both main app and extension
2. Configure server details in the app
3. Grant VPN permission when prompted
4. Test connection and verify traffic routing

## Troubleshooting

### Common Issues

**"Invalid Configuration" Error**
- Verify all server details are correctly entered
- Check bundle identifier matches in extension Info.plist

**"Permission Denied" Error**  
- Ensure Network Extension entitlements are properly configured
- Verify app is signed with valid provisioning profile

**Connection Timeout**
- Check server is running and accessible
- Verify firewall settings allow port 443
- Test server connectivity from other clients

**Extension Crashes**
- Check device logs for crash details
- Verify extension bundle ID is correct
- Ensure all required frameworks are linked

### Debug Tips

1. **Enable Extension Logging**: Use `os_log` in extension for debugging
2. **Test Server Connectivity**: Use tools like `openssl s_client` to test
3. **Monitor Network Traffic**: Use Wireshark to verify protocol behavior
4. **Check System Logs**: Use Console.app to view detailed error messages

## Advanced Features

### Custom DNS
Modify `TrojanPacketTunnelProvider.swift` to use custom DNS servers:
```swift
let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
```

### Split Tunneling
Implement domain-based routing by modifying the tunnel settings:
```swift
ipv4Settings.excludedRoutes = [NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0")]
```

### Multiple Servers
Extend `VPNConfiguration` to support server profiles and quick switching.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This software is for educational and research purposes. Users are responsible for complying with all applicable laws and regulations in their jurisdiction. The authors are not responsible for any misuse of this software.

## Support

For issues and questions:
- Check the troubleshooting section above
- Review iOS Network Extension documentation
- Test with a known working Trojan server
- Ensure proper code signing and entitlements