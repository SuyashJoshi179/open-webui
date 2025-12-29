# OpenWebUI iOS - Multi-Backend Architecture Design

## 🎯 Design Summary

This architecture follows **SOLID principles** and uses **Protocol-Oriented Programming** to create a flexible, maintainable, and extensible AI backend system.

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  ChatView    │  │SettingsView  │  │  ModelsView  │          │
│  │ (SwiftUI)    │  │  (SwiftUI)   │  │  (SwiftUI)   │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ViewModel Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ChatViewModel │  │SettingsVM    │  │  ModelsVM    │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                   │
│         └──────────────────┼──────────────────┘                  │
└───────────────────────────┼─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Backend Manager (Singleton)                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  • Backend Registry                                      │   │
│  │  • Active Backend Management                             │   │
│  │  • Lifecycle Coordination                                │   │
│  │  • Settings Persistence                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AIBackend Protocol                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • id: String                                             │  │
│  │  • name: String                                           │  │
│  │  • isAvailable: Bool                                      │  │
│  │  • settings: AIBackendSettings                            │  │
│  │  • initialize() async throws                              │  │
│  │  • listModels() async -> [AIModel]                        │  │
│  │  • streamGenerate(...) -> AsyncThrowingStream            │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────────────────────────────┬─────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Apple Foundation │  │ OpenAI Compatible│  │   Llama.cpp      │
│     Backend      │  │     Backend      │  │    Backend       │
│                  │  │                  │  │                  │
│ • iOS 26+        │  │ • Cloud API      │  │ • Local GGUF    │
│ • On-device      │  │ • HTTP Requests  │  │ • CPU/GPU       │
│ • Private        │  │ • Any OpenAI API │  │ • Quantized     │
│ • No API key     │  │ • Streaming      │  │ • Fast          │
└──────────────────┘  └──────────────────┘  └──────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│Foundation Models │  │  OpenAI API      │  │  llama.cpp lib   │
│   (System)       │  │  (Network)       │  │   (Embedded)     │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## 🔑 SOLID Principles Applied

### 1️⃣ Single Responsibility Principle (SRP)
```
✅ Each backend handles ONLY its specific AI provider
✅ BackendManager handles ONLY backend coordination
✅ Settings classes handle ONLY configuration
✅ Views handle ONLY presentation
```

**Example:**
```swift
// ❌ BAD - MLXService doing too much
class MLXService {
    func generate() { }
    func chat() { }
    func summarize() { }
    func createEmbedding() { }
    func saveSettings() { }      // ← Settings responsibility
    func loadSettings() { }      // ← Settings responsibility
    func manageModels() { }      // ← Model management responsibility
}

// ✅ GOOD - Single responsibility
class AppleFoundationBackend: AIBackend {
    func initialize() { }
    func listModels() { }
    func streamGenerate() { }
    // Only AI generation responsibilities
}

class AppleFoundationSettings: AIBackendSettings {
    // Only settings responsibilities
}
```

### 2️⃣ Open/Closed Principle (OCP)
```
✅ Open for extension (new backends)
✅ Closed for modification (existing code unchanged)
```

**Example:**
```swift
// ✅ Add new backend WITHOUT modifying existing code
class CustomBackend: AIBackend {
    // Implement protocol
    // No changes needed to BackendManager, ViewModels, or Views!
}

// Register it
BackendManager.shared.registerBackend(CustomBackend())
```

### 3️⃣ Liskov Substitution Principle (LSP)
```
✅ Any AIBackend can replace another
✅ App works correctly with any backend
```

**Example:**
```swift
// ✅ Works with ANY backend implementation
func sendMessage(backend: AIBackend) async {
    let stream = backend.streamGenerate(...)
    for try await chunk in stream {
        // Works regardless of which backend is used
    }
}
```

### 4️⃣ Interface Segregation Principle (ISP)
```
✅ Protocols are minimal and focused
✅ Backends only implement what they need
```

**Example:**
```swift
// ✅ Core protocol - minimal required methods
protocol AIBackend {
    var id: String { get }
    var isAvailable: Bool { get }
    func streamGenerate(...) -> AsyncThrowingStream<String, Error>
}

// ✅ Optional capabilities - separate protocol
protocol AIBackendCapabilities {
    var supportsEmbeddings: Bool { get }
    var supportsVision: Bool { get }
}

// Backends implement only what they support
```

### 5️⃣ Dependency Inversion Principle (DIP)
```
✅ High-level (ViewModels) depend on abstractions (AIBackend protocol)
✅ Low-level (concrete backends) implement abstractions
✅ Not the other way around
```

**Example:**
```swift
// ✅ ViewModel depends on ABSTRACTION
class ChatViewModel {
    let backendManager: BackendManager  // ← Abstraction layer
    
    func sendMessage() async {
        // Uses AIBackend protocol, not concrete implementation
        let backend: AIBackend? = backendManager.activeBackend
    }
}

// ✅ Concrete implementation depends on protocol
class AppleFoundationBackend: AIBackend {  // ← Implements abstraction
    // Implementation details
}
```

## 🎨 Design Patterns Used

### 1. Protocol-Oriented Programming
```swift
protocol AIBackend {
    // Interface definition
}

// All backends conform to same interface
class AppleFoundationBackend: AIBackend { }
class OpenAICompatibleBackend: AIBackend { }
class LlamaCppBackend: AIBackend { }
```

### 2. Singleton Pattern
```swift
class BackendManager {
    static let shared = BackendManager()
    private init() { }  // Prevent multiple instances
}
```

### 3. Registry Pattern
```swift
class BackendManager {
    private var backendRegistry: [String: AIBackend] = [:]
    
    func registerBackend(_ backend: AIBackend) {
        backendRegistry[backend.id] = backend
    }
}
```

### 4. Strategy Pattern
```swift
// Different backends = different strategies
let backend = backendManager.activeBackend
let stream = backend.streamGenerate(...)  // Strategy determines behavior
```

### 5. Factory Pattern (Implicit)
```swift
// BackendManager acts as factory
func getBackend(id: String) -> AIBackend? {
    return backendRegistry[id]
}
```

## 📊 Data Flow

```
User Input
    │
    ▼
[ChatView]
    │
    ▼
[ChatViewModel]
    │
    ├─→ Get active backend ──→ [BackendManager]
    │                                │
    │                                ▼
    │                          [AIBackend Protocol]
    │                                │
    │                          ┌─────┴─────┐
    │                          ▼           ▼
    │                    [Apple Backend] [OpenAI Backend]
    │                          │           │
    │                          ▼           ▼
    └─← Response stream ──────┴───────────┘
         (AsyncThrowingStream<String>)
```

## 🔐 Settings Architecture

```
┌────────────────────────────────────────────────────────┐
│              AIBackendSettings Protocol                 │
│  • backendId: String                                    │
│  • settingsView() -> AnyView                           │
│  • validate() -> Result<Void, SettingsError>           │
└────────────────────┬───────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
┌──────────────┐ ┌──────────┐ ┌──────────────┐
│ Apple        │ │ OpenAI   │ │ Llama.cpp    │
│ Settings     │ │ Settings │ │ Settings     │
│              │ │          │ │              │
│ (minimal)    │ │ • apiURL │ │ • modelPath  │
│              │ │ • apiKey │ │ • threads    │
│              │ │ • orgId  │ │ • gpuLayers  │
└──────────────┘ └──────────┘ └──────────────┘
```

## 🧪 Testing Strategy

### Unit Tests
```
BackendTests/
├── AIBackendProtocolTests.swift       # Protocol conformance
├── BackendManagerTests.swift          # Manager functionality
├── AppleFoundationBackendTests.swift  # Specific backend
├── OpenAICompatibleBackendTests.swift # Specific backend
└── SettingsPersistenceTests.swift     # Settings storage
```

### Integration Tests
```
IntegrationTests/
├── ChatFlowTests.swift              # End-to-end chat
├── BackendSwitchingTests.swift      # Runtime switching
└── SettingsMigrationTests.swift     # Settings upgrades
```

## 📈 Benefits

| Benefit | Description |
|---------|-------------|
| **Maintainability** | Clear separation of concerns, easy to understand |
| **Extensibility** | Add new backends without touching existing code |
| **Testability** | Each component tested independently |
| **Flexibility** | Switch backends at runtime |
| **Type Safety** | Compile-time error checking via protocols |
| **Reusability** | Common interfaces reduce duplication |
| **Scalability** | Easy to add features to all backends |

## 🎯 Key Decisions

### Why Protocol-Oriented?
- Swift's protocols are powerful and flexible
- Better than class inheritance for this use case
- Allows value types and reference types
- Easier testing with protocol mocks

### Why Singleton for BackendManager?
- Single source of truth for active backend
- Centralized lifecycle management
- Easy access from anywhere in app
- Prevents multiple backend states

### Why Async Streams?
- Native Swift concurrency
- Efficient memory usage
- Clean cancellation handling
- Easy to compose and transform

### Why Settings as Protocol?
- Each backend has different needs
- Type-safe configuration
- Easy validation
- Flexible UI generation

## 📚 Resources

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture
- [MIGRATION.md](MIGRATION.md) - Migration guide
- [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md) - Task list

---

**Ready to implement?** Start with [MIGRATION.md](MIGRATION.md) Phase 1!
