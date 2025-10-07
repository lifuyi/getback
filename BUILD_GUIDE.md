# Building Trojan VPN iOS App

This guide walks you through building and deploying the Trojan VPN iOS application.

## Prerequisites

### Development Environment
- **macOS 12.0** or later
- **Xcode 14.0** or later
- **iOS 14.0** deployment target or later
- **Apple Developer Account** (required for Network Extension entitlements)

### Hardware Requirements
- **Physical iOS device** (Network Extensions don't work in iOS Simulator)
- **Lightning/USB-C cable** for device connection

## Project Setup

### 1. Download and Setup Project

```bash
# Clone or download the project
git clone <repository-url>
cd TrojanVPN

# Open in Xcode
open TrojanVPN.xcodeproj
```

### 2. Configure Bundle Identifiers

Update bundle identifiers in both targets:

**Main App Target:**
- Bundle Identifier: `com.yourcompany.trojanvpn`
- Display Name: `Trojan VPN`

**Extension Target:**
- Bundle Identifier: `com.yourcompany.trojanvpn.extension`
- Display Name: `Trojan VPN Extension`

### 3. Configure Signing & Capabilities

#### Main App Target:
1. Select your development team
2. Enable capabilities:
   - **Network Extensions**
   - **Keychain Sharing**

#### Extension Target:
1. Select the same development team
2. Enable capabilities:
   - **Network Extensions**
   - **Keychain Sharing**

### 4. Update Extension Reference

In `TrojanVPNManager.swift`, update line 95:
```swift
providerProtocol.providerBundleIdentifier = "com.yourcompany.trojanvpn.extension"
```

Replace with your actual extension bundle identifier.

## Build Configuration

### Debug Configuration
For development and testing:
```
Build Configuration: Debug
Code Signing: Development
Deployment Target: iOS 14.0
```

### Release Configuration
For distribution:
```
Build Configuration: Release
Code Signing: Distribution
Deployment Target: iOS 14.0
Optimization: -Os (Optimize for Size)
```

## Building the App

### 1. Clean Build Folder
```
Product > Clean Build Folder (⇧⌘K)
```

### 2. Build Main App
```
Product > Build (⌘B)
```

### 3. Build Extension
Select the extension scheme and build:
```
Scheme: TrojanVPNExtension
Product > Build (⌘B)
```

### 4. Build for Device
Connect your iOS device and:
```
1. Select your device from the scheme selector
2. Product > Run (⌘R)
```

## Troubleshooting Build Issues

### Common Build Errors

#### "No matching provisioning profiles found"
**Solution:**
1. Ensure your Apple Developer account is properly configured
2. Generate new provisioning profiles for both targets
3. Download and install profiles in Xcode

#### "Network Extension entitlement not found"
**Solution:**
1. Verify Network Extension capability is enabled
2. Check entitlements file contains:
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
```

#### "Extension bundle identifier mismatch"
**Solution:**
1. Verify extension bundle ID in Info.plist
2. Update reference in TrojanVPNManager.swift
3. Ensure main app and extension have matching team IDs

#### "Code signing failed"
**Solution:**
1. Check provisioning profile validity
2. Ensure device is registered in developer portal
3. Verify certificate is not expired

### Extension-Specific Issues

#### "Extension crashes on launch"
**Solution:**
1. Check extension's principal class name in Info.plist
2. Verify all required frameworks are linked
3. Review crash logs in Console.app

#### "VPN configuration invalid"
**Solution:**
1. Verify all required parameters are provided
2. Check server address format
3. Ensure password is not empty

## Testing the Build

### 1. Install on Device
```bash
# Via Xcode
Product > Run (⌘R)

# Via command line (if using xcodebuild)
xcodebuild -project TrojanVPN.xcodeproj -scheme TrojanVPN -destination 'platform=iOS,name=YourDevice' install
```

### 2. Grant Permissions
When first launching:
1. App will request VPN configuration permission
2. Accept the system prompt
3. Verify VPN profile appears in Settings > VPN

### 3. Test Connection
1. Configure server details in the app
2. Tap "Connect"
3. Verify VPN status changes to "Connected"
4. Test internet connectivity

## Distribution

### App Store Distribution

#### 1. Archive Build
```
Product > Archive
```

#### 2. Export for App Store
1. Select archive in Organizer
2. Click "Distribute App"
3. Choose "App Store Connect"
4. Follow the upload wizard

#### 3. Submit for Review
1. Complete app metadata in App Store Connect
2. Add required screenshots
3. Submit for Apple review

### Enterprise Distribution

#### 1. Enterprise Certificate
Ensure you have an Apple Enterprise certificate

#### 2. Export for Enterprise
```
Product > Archive
Window > Organizer
Select Archive > Distribute App > Enterprise
```

#### 3. Generate IPA
Export signed IPA for internal distribution

## Performance Optimization

### Build Settings for Release

#### Swift Compiler
```
Optimization Level: Optimize for Speed [-O]
Compilation Mode: Whole Module Optimization
```

#### Apple Clang
```
Optimization Level: Fastest, Smallest [-Os]
Dead Code Stripping: YES
```

#### Linking
```
Strip Debug Symbols During Copy: YES
Strip Linked Product: YES
```

### Code Optimization Tips

1. **Minimize Extension Memory Usage**
   - Network Extensions have strict memory limits
   - Use autoreleasing pools for large data processing
   - Avoid retaining large objects unnecessarily

2. **Optimize Packet Processing**
   - Use efficient data structures
   - Minimize memory allocations in hot paths
   - Consider packet batching for better performance

3. **Background Processing**
   - Handle app state transitions properly
   - Maintain VPN connection when app is backgrounded
   - Implement proper cleanup on termination

## Debugging

### Enable Console Logging
```swift
import os.log

let logger = Logger(subsystem: "com.yourcompany.trojanvpn", category: "networking")
logger.info("Connection established")
```

### Device Logs
View extension logs in Console.app:
1. Connect device to Mac
2. Open Console.app
3. Filter by bundle identifier
4. Monitor real-time logs

### Network Debugging
Use Network Link Conditioner for testing:
1. Install on device via Settings > Developer
2. Simulate poor network conditions
3. Verify VPN handles connection issues gracefully

## Security Considerations

### Code Signing
- Always use valid certificates
- Verify code signature before distribution
- Enable Hardened Runtime for additional security

### Network Security
- Validate all server certificates
- Use proper TLS configuration
- Implement certificate pinning if needed

### Data Protection
- Enable Data Protection for all files
- Use Keychain for sensitive data storage
- Implement secure data transmission

## Final Checklist

Before releasing:
- [ ] All build warnings resolved
- [ ] Extension tested on multiple devices
- [ ] VPN functionality verified
- [ ] Memory usage within limits
- [ ] Battery impact minimized
- [ ] Error handling comprehensive
- [ ] User interface polished
- [ ] Documentation complete

## Support

For build issues:
1. Check Apple Developer documentation
2. Review Xcode console output
3. Test on different device models
4. Verify server configuration
5. Contact Apple Developer Support if needed