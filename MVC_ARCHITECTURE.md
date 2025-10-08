# TrojanVPN MVC Architecture

This project follows a proper Model-View-Controller (MVC) architecture where iOS and macOS applications share the same **Models** and **Controllers**, but have separate **Views** optimized for each platform.

## Project Structure

```
TrojanVPN/
├── Package.swift                      # Swift Package Manager configuration
├── Sources/
│   ├── TrojanVPNModels/              # 📊 PURE DATA MODELS (Foundation Layer)
│   │   └── ServerProfile.swift       # Pure server configuration model
│   │
│   ├── TrojanVPNCore/                # 🎮 SHARED: Controllers + Utilities
│   │   ├── Controllers/              # 🎮 Business Logic Controllers
│   │   │   ├── TrojanVPNManager.swift      # Main VPN connection controller
│   │   │   ├── NetworkMonitor.swift        # Network state monitoring
│   │   │   ├── KillSwitchManager.swift     # Kill switch functionality
│   │   │   └── ServerProfileManager.swift  # Server profile management
│   │   └── Utilities/                # 🛠️ Shared Utilities
│   │       ├── KeychainManager.swift       # Secure storage
│   │       ├── Constants.swift             # App constants
│   │       └── Extensions.swift            # Swift extensions
│   │
│   ├── TrojanVPNExtension/           # 🔗 SHARED: Network Extension
│   │   ├── TrojanPacketTunnelProvider.swift
│   │   ├── TrojanConnection.swift
│   │   ├── TrojanProtocol.swift
│   │   ├── PacketParser.swift
│   │   ├── Info.plist
│   │   └── TrojanVPNExtension.entitlements
│   │
│   ├── TrojanVPNiOS/                # 📱 iOS-specific Views
│   │   ├── ContentView.swift             # Main iOS interface
│   │   ├── ServerListView.swift          # Server list for iOS
│   │   ├── TrojanVPNApp.swift           # iOS app entry point
│   │   └── TestViewController.swift      # iOS testing interface
│   │
│   ├── TrojanVPNmacOS/              # 💻 macOS-specific Views
│   │   ├── ContentView_macOS.swift       # Main macOS interface
│   │   ├── SidebarView.swift            # macOS sidebar navigation
│   │   ├── ServerConfigView.swift       # macOS server configuration
│   │   ├── TrojanVPNApp_macOS.swift     # macOS app entry point
│   │   ├── TrojanVPNManager_macOS.swift # macOS-specific VPN management
│   │   └── NetworkMonitor_macOS.swift    # macOS-specific network monitoring
│   │
│   └── TrojanVPNDemo/               # 🧪 Demo Application
│       └── main.swift                   # Command line demo
│
├── Resources/                       # 📁 Platform Resources
│   ├── iOS/
│   │   ├── Info.plist
│   │   └── TrojanVPN.entitlements
│   └── macOS/
│
└── Tests/                          # 🧪 Unit Tests
    └── TrojanVPNTests/
```

## Dependency Architecture

The project follows a **layered dependency structure** where each layer only depends on layers below it:

```
┌─────────────────────────────────────────────────────────────┐
│                        📱 iOS Views                        │
│                       💻 macOS Views                       │
├─────────────────────────────────────────────────────────────┤
│                     🔌 Network Extension                   │
├─────────────────────────────────────────────────────────────┤
│                  🎮 TrojanVPNCore (Controllers)            │
│                     🛠️ Utilities                           │
├─────────────────────────────────────────────────────────────┤
│                   📊 TrojanVPNModels                       │
│                   (Foundation Layer)                       │
└─────────────────────────────────────────────────────────────┘
```

**Benefits of this layered approach:**
- 📊 **Models** can be used by any layer (most reusable)
- 🎮 **Controllers** can be tested independently of UI
- 📱 **Views** can be swapped out without changing business logic
- 🔌 **Extensions** can access models and controllers safely

## Architecture Principles

### 🔗 Shared Components (Cross-Platform)

#### 📊 Models Library (`Sources/TrojanVPNModels/`)
- **ServerProfile.swift**: Pure data model for VPN server configurations
- **Zero dependencies** - Foundation layer that can be imported anywhere
- Contains only data structures and basic data manipulation methods
- **No business logic** - just data containers with helper methods
- Can be reused by other apps, extensions, or even server-side Swift

#### 🎮 Controllers (`Sources/TrojanVPNCore/Controllers/`)
- **TrojanVPNManager.swift**: Core VPN connection management logic
- **NetworkMonitor.swift**: Network state monitoring and auto-reconnection
- **KillSwitchManager.swift**: Kill switch functionality to prevent data leaks
- **ServerProfileManager.swift**: Business logic for managing server profiles
- Business logic with no UI dependencies
- Platform-agnostic implementations using `#if os()` where needed
- **Depends on**: TrojanVPNModels

#### 🛠️ Utilities (`Sources/TrojanVPNCore/Utilities/`)
- **KeychainManager.swift**: Secure credential storage
- **Constants.swift**: Application-wide constants
- **Extensions.swift**: Swift language extensions
- Helper classes and extensions used across the application
- **Depends on**: TrojanVPNModels (for type-safe keychain operations)

### 📱 iOS Views (`Sources/TrojanVPNiOS/`)
- **ContentView.swift**: Main iOS interface optimized for touch navigation
- **ServerListView.swift**: iOS-specific server list with mobile UI patterns
- **TrojanVPNApp.swift**: iOS app lifecycle and entry point
- Uses iOS-specific UI patterns (navigation, touch interactions)

### 💻 macOS Views (`Sources/TrojanVPNmacOS/`)
- **ContentView_macOS.swift**: Main macOS interface optimized for desktop
- **SidebarView.swift**: macOS sidebar navigation pattern
- **ServerConfigView.swift**: Desktop-optimized server configuration
- **TrojanVPNApp_macOS.swift**: macOS app lifecycle and entry point
- Uses macOS-specific UI patterns (sidebars, multi-window support)

### 🔌 Network Extension (`Sources/TrojanVPNExtension/`)
- Shared network extension code for both platforms
- Handles the actual VPN tunnel implementation
- Platform-agnostic network packet processing

## Benefits of This Architecture

### ✅ Code Reusability
- **Models and Controllers** are shared between iOS and macOS
- Reduces duplication and maintenance overhead
- Business logic implemented once, used everywhere

### ✅ Platform Optimization
- **Views** are optimized for each platform's UI guidelines
- iOS views use mobile-first design patterns
- macOS views use desktop interaction paradigms

### ✅ Maintainability
- Clear separation of concerns
- Easy to test business logic independent of UI
- Simple to add new platforms (tvOS, watchOS) in the future

### ✅ Scalability
- New features added to Controllers are automatically available on both platforms
- UI can be independently updated per platform
- Easy to swap out UI frameworks while keeping business logic

## Development Workflow

### Adding New Features
1. **Model Changes**: Add/modify models in `TrojanVPNCore/Models/`
2. **Business Logic**: Implement in `TrojanVPNCore/Controllers/`
3. **iOS UI**: Create/update views in `TrojanVPNiOS/`
4. **macOS UI**: Create/update views in `TrojanVPNmacOS/`

### Platform-Specific Considerations
- Use `#if os(iOS)` and `#if os(macOS)` sparingly, only in shared Controllers when absolutely necessary
- Keep platform-specific code in respective View modules
- Prefer protocol-based abstractions over conditional compilation

## Import Structure

```swift
// In iOS/macOS Views
import TrojanVPNModels  // Access to pure data models
import TrojanVPNCore    // Access to controllers and utilities
import SwiftUI          // Platform UI framework

// In Controllers (TrojanVPNCore)
import TrojanVPNModels  // Access to data models
import Foundation
import NetworkExtension
import Combine
// NO UI framework imports - keeps it platform agnostic

// In Models (TrojanVPNModels)
import Foundation       // Only Foundation - zero dependencies
// NO imports of business logic or UI frameworks

// In Network Extension
import TrojanVPNModels  // Access to data models
import TrojanVPNCore    // Access to controllers if needed
import NetworkExtension
import Foundation
```

**Import Rules:**
- 📊 **Models**: Only import Foundation (zero dependencies)
- 🎮 **Controllers**: Import Models + system frameworks (no UI)
- 📱 **Views**: Import Models + Controllers + UI frameworks
- 🔌 **Extensions**: Import Models + Controllers + system frameworks

This architecture ensures that your TrojanVPN app maintains a clean separation between shared business logic and platform-specific user interfaces, making it easier to maintain and extend across both iOS and macOS platforms.