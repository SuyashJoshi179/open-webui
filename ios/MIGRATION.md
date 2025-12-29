# Migration Guide: Refactoring to Multi-Backend Architecture

## Overview
This guide walks through migrating the existing OpenWebUI iOS app to use the new multi-backend architecture.

## Phase 1: Add Protocol Layer (Week 1)

### Step 1.1: Add Protocol Files
Already created:
- `Services/Protocols/AIBackend.swift`
- `Services/Protocols/AIBackendSettings.swift`
- `Services/BackendManager.swift`

### Step 1.2: Create Folder Structure
```bash
mkdir -p OpenWebUI/Services/Backends
mkdir -p OpenWebUI/Services/Settings
```

### Step 1.3: Update Xcode Project
Add new files to the Xcode project in the appropriate groups.

## Phase 2: Refactor Existing Services (Week 1-2)

### Step 2.1: Refactor MLXService to AppleFoundationBackend

**Current:** `MLXService.swift`
**New:** `Backends/AppleFoundationBackend.swift`

**Changes needed:**
1. Rename class from `MLXService` to `AppleFoundationBackend`
2. Implement `AIBackend` protocol
3. Extract settings into `AppleFoundationSettings`
4. Update method signatures to match protocol

**Example:**
```swift
class AppleFoundationBackend: AIBackend {
    let id = "apple-foundation"
    let name = "Apple Intelligence"
    let description = "On-device AI using Apple's Foundation Models"
    let iconName = "apple.logo"
    
    // ... implement protocol methods
}
```

### Step 2.2: Refactor OpenAIService to OpenAICompatibleBackend

**Current:** `OpenAIService.swift`
**New:** `Backends/OpenAICompatibleBackend.swift`

**Changes needed:**
1. Rename class from `OpenAIService` to `OpenAICompatibleBackend`
2. Implement `AIBackend` protocol
3. Move API URL and key to `OpenAICompatibleSettings`
4. Update method signatures to match protocol

**Settings structure:**
```swift
struct OpenAICompatibleSettings: AIBackendSettings {
    var backendId = "openai-compatible"
    var apiURL: String = ""
    var apiKey: String = ""
    var organizationId: String? = nil
    
    // ... implement protocol methods
}
```

## Phase 3: Update ViewModels (Week 2)

### Step 3.1: Update ChatViewModel

**Current code:**
```swift
class ChatViewModel: ObservableObject {
    private let mlxService = MLXService.shared
    
    func sendMessage(_ content: String) async {
        // Direct MLXService calls
        for try await chunk in mlxService.streamGenerate(...) {
            // ...
        }
    }
}
```

**New code:**
```swift
class ChatViewModel: ObservableObject {
    @ObservedObject private var backendManager = BackendManager.shared
    
    func sendMessage(_ content: String) async {
        guard let backend = backendManager.activeBackend else { return }
        
        let context = AIContext(
            chatId: chat.id,
            systemPrompt: nil,
            conversationHistory: messages
        )
        
        let stream = backend.streamGenerate(
            model: selectedModel,
            prompt: content,
            context: context,
            parameters: .default
        )
        
        for try await chunk in stream {
            // ...
        }
    }
}
```

### Step 3.2: Update ModelsViewModel

**Current:**
```swift
func loadModels() async {
    let mlxModels = await MLXService.shared.listLocalModels()
    let openAIModels = await OpenAIService.shared.listModels()
    // ...
}
```

**New:**
```swift
func loadModels() async {
    do {
        let models = try await BackendManager.shared.getAllModels()
        self.models = models
    } catch {
        // Handle error
    }
}
```

## Phase 4: Update UI (Week 2-3)

### Step 4.1: Update SettingsView

Add navigation link to backend selection:
```swift
NavigationLink(destination: BackendSelectionView()) {
    HStack {
        Image(systemName: "cpu")
        Text("AI Backend")
        Spacer()
        if let backend = backendManager.activeBackend {
            Text(backend.name)
                .foregroundStyle(.secondary)
        }
    }
}
```

### Step 4.2: Update App Initialization

In `OpenWebUIApp.swift`:
```swift
@main
struct OpenWebUIApp: App {
    init() {
        setupBackends()
    }
    
    private func setupBackends() {
        let backendManager = BackendManager.shared
        
        // Register all backends
        backendManager.registerBackend(AppleFoundationBackend())
        backendManager.registerBackend(OpenAICompatibleBackend())
        backendManager.registerBackend(LlamaCppBackend())
        backendManager.registerBackend(LiteRTBackend())
        
        // Initialize in background
        Task {
            await backendManager.initializeAllBackends()
        }
    }
    
    var body: some Scene {
        // ...
    }
}
```

## Phase 5: Add New Backends (Week 3-4)

### Step 5.1: Add Llama.cpp Backend
1. Add llama.cpp Swift bindings or C++ wrapper
2. Implement `LlamaCppBackend` (already scaffolded)
3. Test with GGUF models

### Step 5.2: Add LiteRT Backend
1. Add TensorFlow Lite Swift package
2. Implement `LiteRTBackend` (already scaffolded)
3. Test with .tflite models

## Phase 6: Testing & Refinement (Week 4)

### Test Checklist
- [ ] All backends register correctly
- [ ] Backend switching works
- [ ] Settings persist across app restarts
- [ ] Chat works with each backend
- [ ] Models list correctly for each backend
- [ ] Performance metrics track correctly
- [ ] Error handling works properly
- [ ] UI updates correctly on backend change

## Code Removal

After migration, these files can be removed:
- Old `MLXService.swift` (replaced by `AppleFoundationBackend.swift`)
- Old `OpenAIService.swift` (replaced by `OpenAICompatibleBackend.swift`)
- Direct `@AppStorage` usage for API settings (now in backend settings)

## Breaking Changes

### For Other Developers
If you're working on this codebase, these changes will affect you:

1. **MLXService → AppleFoundationBackend**
   ```swift
   // Old
   let service = MLXService.shared
   
   // New
   let backend = BackendManager.shared.getBackend(id: "apple-foundation")
   ```

2. **Direct service calls → BackendManager**
   ```swift
   // Old
   await mlxService.generate(...)
   
   // New
   guard let backend = BackendManager.shared.activeBackend else { return }
   backend.streamGenerate(...)
   ```

3. **Settings access**
   ```swift
   // Old
   @AppStorage("apiURL") var apiURL: String = ""
   
   // New
   let settings = backend.settings as? OpenAICompatibleSettings
   ```

## Timeline

| Week | Phase | Tasks |
|------|-------|-------|
| 1 | Protocol Layer | Add protocols, create BackendManager |
| 1-2 | Refactor Services | Convert MLXService and OpenAIService |
| 2 | Update ViewModels | Update all ViewModels to use BackendManager |
| 2-3 | Update UI | Add backend selection, update settings |
| 3-4 | New Backends | Implement Llama.cpp and LiteRT backends |
| 4 | Testing | Comprehensive testing and bug fixes |

## Support

For questions or issues during migration:
1. Check ARCHITECTURE.md for design details
2. Review example implementations in `Backends/` folder
3. Test each phase before proceeding to the next

## Benefits After Migration

✅ **Extensibility**: Add new backends without modifying existing code
✅ **Maintainability**: Clear separation of concerns, easier to understand
✅ **Testability**: Each backend can be tested independently
✅ **Flexibility**: Runtime backend switching
✅ **Type Safety**: Protocol-oriented design ensures compile-time safety
✅ **SOLID Principles**: Follows all five SOLID principles
