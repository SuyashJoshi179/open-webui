# OpenWebUI iOS Architecture

## Overview
This document describes the architecture for supporting multiple AI backends in OpenWebUI iOS app, following SOLID principles.

## Design Principles

### 1. Single Responsibility Principle (SRP)
- Each backend service handles only its specific AI provider
- Settings management is separate from inference logic
- UI components only handle presentation

### 2. Open/Closed Principle (OCP)
- System is open for extension (new backends) but closed for modification
- New backends can be added without changing existing code

### 3. Liskov Substitution Principle (LSP)
- All backends are interchangeable through the `AIBackend` protocol
- App works correctly regardless of which backend is active

### 4. Interface Segregation Principle (ISP)
- Protocols are focused and minimal
- Backends only implement what they need

### 5. Dependency Inversion Principle (DIP)
- High-level modules (ViewModels) depend on abstractions (protocols)
- Low-level modules (concrete backends) implement those abstractions

## Architecture Components

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  ChatView    │  │ SettingsView │  │  ModelsView  │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                  │           │
└─────────┼─────────────────┼──────────────────┼──────────┘
          │                 │                  │
┌─────────┼─────────────────┼──────────────────┼──────────┐
│         ▼                 ▼                  ▼           │
│  ┌──────────────────────────────────────────────────┐   │
│  │        BackendManager (Singleton)                 │   │
│  │  - manages active backend                         │   │
│  │  - provides backend registry                      │   │
│  │  - handles backend switching                      │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │                                    │
│         ┌───────────┼───────────┬──────────────┐        │
│         ▼           ▼           ▼              ▼        │
│  ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌─────────────┐ │
│  │  Apple   │ │  OpenAI  │ │ Llama.  │ │   LiteRT    │ │
│  │Foundation│ │Compatible│ │  cpp    │ │   Backend   │ │
│  │  Model   │ │ Endpoint │ │ Backend │ │             │ │
│  └──────────┘ └──────────┘ └─────────┘ └─────────────┘ │
│       │            │            │              │         │
│       └────────────┴────────────┴──────────────┘         │
│                    │                                     │
│                    ▼                                     │
│            AIBackend Protocol                            │
│            AIBackendSettings Protocol                    │
└──────────────────────────────────────────────────────────┘
```

## Protocol Definitions

### AIBackend Protocol
Core protocol that all backends must implement:
```swift
protocol AIBackend {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var isAvailable: Bool { get }
    var settings: AIBackendSettings { get }
    
    func initialize() async throws
    func listModels() async -> [AIModel]
    func streamGenerate(
        model: String,
        prompt: String,
        context: AIContext
    ) -> AsyncThrowingStream<String, Error>
    func checkAvailability() async -> Bool
}
```

### AIBackendSettings Protocol
Settings management for each backend:
```swift
protocol AIBackendSettings: Codable {
    var backendId: String { get }
    func settingsView() -> AnyView
    func validate() -> Result<Void, SettingsError>
}
```

### AIModel
Common model representation:
```swift
struct AIModel: Identifiable {
    let id: String
    let name: String
    let backendId: String
    let capabilities: ModelCapabilities
    let metadata: [String: Any]?
}
```

## Backend Implementations

### 1. Apple Foundation Model Backend
- Uses iOS 26+ FoundationModels framework
- Settings: None (uses system configuration)
- Features: On-device, private, no API key needed

### 2. OpenAI Compatible Backend
- Works with OpenAI API and compatible endpoints
- Settings: API URL, API Key, Organization ID (optional)
- Features: Cloud-based, flexible model selection

### 3. Llama.cpp Backend
- Runs quantized models locally using llama.cpp
- Settings: Model path, context size, threads, GPU layers
- Features: Local inference, GGUF format support

### 4. LiteRT Backend
- Uses Google's LiteRT (formerly TensorFlow Lite)
- Settings: Model path, number of threads, use GPU delegate
- Features: Mobile-optimized, efficient inference

## Backend Manager

Singleton that manages all backends:
```swift
class BackendManager: ObservableObject {
    @Published var activeBackend: AIBackend?
    @Published var availableBackends: [AIBackend]
    
    func registerBackend(_ backend: AIBackend)
    func setActiveBackend(_ backendId: String)
    func getBackend(id: String) -> AIBackend?
}
```

## Settings Architecture

Each backend provides its own settings view:
```swift
struct BackendSettingsView: View {
    let backend: AIBackend
    
    var body: some View {
        backend.settings.settingsView()
    }
}
```

## Usage Example

```swift
// In ChatViewModel
class ChatViewModel: ObservableObject {
    @ObservedObject var backendManager = BackendManager.shared
    
    func sendMessage(_ text: String) async {
        guard let backend = backendManager.activeBackend else { return }
        
        let stream = backend.streamGenerate(
            model: selectedModel,
            prompt: text,
            context: chatContext
        )
        
        for try await chunk in stream {
            // Handle response
        }
    }
}
```

## Migration Strategy

### Phase 1: Create Protocol Layer
1. Define protocols (AIBackend, AIBackendSettings, etc.)
2. Create BackendManager
3. Define common models (AIModel, AIContext)

### Phase 2: Refactor Existing Backends
1. Refactor MLXService to implement AIBackend
2. Refactor OpenAIService to implement AIBackend
3. Update ViewModels to use BackendManager

### Phase 3: Add New Backends
1. Implement LlamaCppBackend
2. Implement LiteRTBackend
3. Add backend selection UI

### Phase 4: Settings Integration
1. Create settings protocols
2. Implement backend-specific settings views
3. Add persistence layer for settings

## File Structure

```
Services/
├── Protocols/
│   ├── AIBackend.swift
│   ├── AIBackendSettings.swift
│   ├── AIModel.swift
│   └── AIContext.swift
├── BackendManager.swift
├── Backends/
│   ├── AppleFoundationBackend.swift
│   ├── OpenAICompatibleBackend.swift
│   ├── LlamaCppBackend.swift
│   └── LiteRTBackend.swift
└── Settings/
    ├── AppleFoundationSettings.swift
    ├── OpenAICompatibleSettings.swift
    ├── LlamaCppSettings.swift
    └── LiteRTSettings.swift

Views/
├── Settings/
│   ├── BackendSettingsView.swift
│   ├── BackendSelectionView.swift
│   └── [Backend-specific settings views]
```

## Benefits

1. **Maintainability**: Clear separation of concerns, easy to understand
2. **Extensibility**: Add new backends without modifying existing code
3. **Testability**: Each backend can be tested independently
4. **Flexibility**: Switch backends at runtime
5. **Type Safety**: Protocol-oriented design ensures compile-time safety
6. **Reusability**: Common interfaces reduce code duplication

## Testing Strategy

1. **Unit Tests**: Test each backend independently
2. **Protocol Tests**: Verify all backends conform to protocols
3. **Integration Tests**: Test BackendManager with multiple backends
4. **UI Tests**: Verify backend switching and settings persistence
