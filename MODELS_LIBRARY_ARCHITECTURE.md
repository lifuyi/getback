# TrojanVPN Models Library Architecture

## Overview

The TrojanVPN project now uses a **layered architecture** with the Models extracted into a separate, foundational library. This follows the principle of **dependency inversion** where the most stable, reusable components (data models) have zero dependencies and can be imported by any layer.

## Layered Dependency Structure

```
┌─────────────────────────────────────────────────────────────┐
│  📱 TrojanVPNiOS    💻 TrojanVPNmacOS    🧪 TrojanVPNDemo  │  ← Apps/Views
├─────────────────────────────────────────────────────────────┤
│              🔌 TrojanVPNExtension                         │  ← Network Extension
├─────────────────────────────────────────────────────────────┤
│         🎮 TrojanVPNCore (Controllers + Utilities)         │  ← Business Logic
├─────────────────────────────────────────────────────────────┤
│              📊 TrojanVPNModels                            │  ← Foundation Layer
│                 (Zero Dependencies)                        │
└─────────────────────────────────────────────────────────────┘
```

## Models Library Benefits

### ✅ **Maximum Reusability**
- Can be imported by **any target** without bringing unnecessary dependencies
- Usable in network extensions, background services, command-line tools
- Can be shared with other apps or even server-side Swift projects

### ✅ **Zero Dependencies**
- Only imports `Foundation` - no business logic, no UI frameworks
- Fastest compilation and smallest footprint
- Can be used in the most constrained environments

### ✅ **Pure Data Focus**
- Contains only data structures and basic data manipulation
- No business logic that might change based on app requirements
- Stable, well-defined API surface

### ✅ **Type Safety Across Layers**
- All layers work with the same data types
- No data transformation needed between layers
- Compiler ensures consistency across the entire stack

## What's in Each Layer

### 📊 TrojanVPNModels (Foundation)
```swift
// Pure data models with zero dependencies
public struct ServerProfile: Codable, Identifiable, Hashable {
    // Data properties only
    public let id: UUID
    public var name: String
    public var serverAddress: String
    // ... other properties
    
    // Pure data manipulation methods (no side effects)
    public func withUpdatedConnection() -> ServerProfile
    public func withToggledFavorite() -> ServerProfile
    public func forExport() -> ServerProfile
}
```

**Characteristics:**
- ✅ No side effects
- ✅ No external dependencies (except Foundation)
- ✅ Immutable-friendly design with `with*` methods
- ✅ Pure functions only

### 🎮 TrojanVPNCore (Business Logic)
```swift
// Controllers that manage models and provide business logic
import TrojanVPNModels

public class ServerProfileManager: ObservableObject {
    @Published public var profiles: [ServerProfile] = []
    
    // Business logic methods with side effects
    public func addProfile(_ profile: ServerProfile)
    public func deleteProfile(_ profile: ServerProfile)
    public func saveProfiles() // Persistence
    // ... other business operations
}
```

**Characteristics:**
- ✅ Imports and works with TrojanVPNModels
- ✅ Contains business logic and side effects
- ✅ Manages persistence, validation, and workflows
- ✅ Platform-agnostic (no UI dependencies)

### 📱💻 Platform Views
```swift
// UI layers that consume both models and controllers
import TrojanVPNModels
import TrojanVPNCore
import SwiftUI

struct ServerListView: View {
    @StateObject private var profileManager = ServerProfileManager.shared
    
    var body: some View {
        List(profileManager.profiles) { profile in
            ServerRowView(profile: profile)
        }
    }
}
```

**Characteristics:**
- ✅ Imports both Models and Core
- ✅ Platform-specific UI optimizations
- ✅ Binds to business logic controllers
- ✅ Works directly with model types

## Import Strategy

### Minimalist Imports
Each layer only imports what it absolutely needs:

```swift
// 📊 Models: Minimal dependencies
import Foundation

// 🎮 Controllers: Models + system frameworks
import TrojanVPNModels
import Foundation
import Combine
import NetworkExtension

// 📱 Views: Models + Controllers + UI
import TrojanVPNModels
import TrojanVPNCore
import SwiftUI

// 🔌 Extension: Models + Controllers + system
import TrojanVPNModels
import TrojanVPNCore
import NetworkExtension
```

## Package.swift Structure

```swift
let package = Package(
    name: "TrojanVPN",
    products: [
        .library(name: "TrojanVPNModels", targets: ["TrojanVPNModels"]),     // Foundation
        .library(name: "TrojanVPNCore", targets: ["TrojanVPNCore"]),         // Business Logic
        .library(name: "TrojanVPNiOS", targets: ["TrojanVPNiOS"]),           // iOS Views
        .library(name: "TrojanVPNmacOS", targets: ["TrojanVPNmacOS"]),       // macOS Views
        .library(name: "TrojanVPNExtension", targets: ["TrojanVPNExtension"]) // Network Extension
    ],
    targets: [
        .target(name: "TrojanVPNModels", dependencies: []),                                    // Zero deps
        .target(name: "TrojanVPNCore", dependencies: ["TrojanVPNModels"]),                     // Depends on Models
        .target(name: "TrojanVPNiOS", dependencies: ["TrojanVPNModels", "TrojanVPNCore"]),     // Depends on both
        .target(name: "TrojanVPNmacOS", dependencies: ["TrojanVPNModels", "TrojanVPNCore"]),   // Depends on both
        .target(name: "TrojanVPNExtension", dependencies: ["TrojanVPNModels", "TrojanVPNCore"]) // Depends on both
    ]
)
```

## Migration Benefits

### Before (Monolithic Core)
```
TrojanVPNCore
├── Models + Controllers + Utilities (mixed)
└── Heavy dependencies pulled everywhere
```

**Problems:**
- ❌ Network extensions pulled in unnecessary business logic
- ❌ Other apps couldn't reuse just the models
- ❌ Tight coupling between data and business logic
- ❌ Harder to test models in isolation

### After (Layered Libraries)
```
TrojanVPNModels (Foundation) ← Zero dependencies
TrojanVPNCore (Business)     ← Depends on Models
Views & Extensions           ← Depend on what they need
```

**Benefits:**
- ✅ Network extensions only import what they need
- ✅ Models can be reused in any context
- ✅ Clear separation of concerns
- ✅ Easy to test each layer independently

## Future Extensibility

This architecture makes it easy to:

1. **Add new platforms** (tvOS, watchOS) - just create new View libraries
2. **Create companion apps** - reuse Models and Core in separate apps  
3. **Build server tools** - use Models in server-side Swift applications
4. **Develop plugins** - Models can be shared with third-party extensions
5. **Write tests** - Each layer can be tested in isolation

## Real-World Example

A typical user action flows through the layers:

```swift
// 1. User taps "Connect" in UI (View layer)
Button("Connect") { profileManager.connectToProfile(selectedProfile) }

// 2. Business logic handles the request (Controller layer)
func connectToProfile(_ profile: ServerProfile) {
    let updatedProfile = profile.withUpdatedConnection()  // Model method
    vpnManager.connect(to: updatedProfile)                // Business logic
    saveProfiles()                                        // Persistence
}

// 3. Data flows back through the layers
// VPN connects → Updates model → Publishes change → UI updates
```

Each layer has a clear responsibility and clean interfaces between them.

This architecture provides a solid foundation for building maintainable, testable, and scalable cross-platform applications.