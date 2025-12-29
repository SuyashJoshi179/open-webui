# OpenWebUI iOS Architecture

## Design Philosophy

This iOS app follows a **model-centric architecture** where users select AI **models** rather than backends. Each model belongs to a backend provider and has its own configuration.

## Core Principles

### 1. Model-First Design
- **Users select models**, not backends
- Each model has its own configuration (API URL, token, parameters)
- Backends manage their model collections
- Models are the primary unit of interaction

### 2. Backend as Model Provider
- Backends are **model providers**
- Each backend can expose multiple configured models
- Backend-level settings apply to all models from that backend
- Some backends (Apple Intelligence) provide fixed models
- Others (OpenAI Compatible) allow user-defined models

### 3. Configuration Hierarchy
```
Backend
├── Backend-level settings (shared across all models)
└── Models
    ├── Model 1 (model-specific configuration)
    ├── Model 2 (model-specific configuration)
    └── Model N (model-specific configuration)
```

## Architecture Components

```
┌──────────────────────────────────────────────────────────┐
│                     UI Layer                              │
│  ┌────────────┐  ┌────────────┐  ┌───────────────────┐  │
│  │  ChatView  │  │ ModelsView │  │  SettingsView     │  │
│  │            │  │            │  │                   │  │
│  │ Select     │  │ Browse &   │  │ Configure         │  │
│  │ Model      │  │ Configure  │  │ Model Settings    │  │
│  └─────┬──────┘  └──────┬─────┘  └─────────┬─────────┘  │
└────────┼─────────────────┼──────────────────┼────────────┘
         │                 │                  │
┌────────┼─────────────────┼──────────────────┼────────────┐
│        ▼                 ▼                  ▼            │
│  ┌──────────────────────────────────────────────────┐   │
│  │          BackendManager                          │   │
│  │  - Aggregates models from all backends           │   │
│  │  - Provides unified model list                   │   │
│  │  - Manages active model selection                │   │
│  │  - Delegates operations to parent backend        │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │                                    │
│         ┌───────────┼──────────────┬─────────────┐      │
│         ▼           ▼              ▼             ▼      │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌───────────┐ │
│  │  Apple   │ │  OpenAI  │ │  Llama    │ │  LiteRT   │ │
│  │Foundation│ │Compatible│ │  .cpp     │ │  Backend  │ │
│  │ Backend  │ │ Backend  │ │  Backend  │ │           │ │
│  │          │ │          │ │           │ │           │ │
│  │ Models:  │ │ Models:  │ │ Models:   │ │ Models:   │ │
│  │ • AI(1)  │ │ • GPT-4  │ │ • Llama2  │ │ • Gemma   │ │
│  │ (fixed)  │ │ • Claude │ │ • Mistral │ │ • ...     │ │
│  │          │ │ • Custom │ │ • ...     │ │           │ │
│  └──────────┘ └──────────┘ └───────────┘ └───────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Data Models

### ConfiguredAIModel
The primary unit users interact with - a configured model instance.

```swift
struct ConfiguredAIModel: Identifiable, Codable {
    let id: UUID
    let backendId: String
    var displayName: String
    let modelIdentifier: String
    
    // Model-specific configuration
    var configuration: ModelConfiguration
    
    // Capabilities
    let capabilities: ModelCapabilities
    
    // Reference to parent backend (not stored)
    var backend: AIBackend? { 
        BackendManager.shared.getBackend(id: backendId)
    }
}
```

### ModelConfiguration
Per-model settings.

```swift
struct ModelConfiguration: Codable {
    // Connection settings
    var apiURL: String?
    var apiKey: String?
    var organizationId: String?
    
    // Generation parameters
    var maxTokens: Int = 2048
    var temperature: Double = 0.7
    var topP: Double = 0.9
    var topK: Int = 50
    
    // Local model settings (for Llama.cpp, LiteRT)
    var modelPath: String?
    var contextSize: Int?
    var gpuLayers: Int?
    var threads: Int?
}
```

## Protocol Definitions

### AIBackend Protocol
```swift
protocol AIBackend: AnyObject {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var iconName: String { get }
    
    // Backend-level settings (applies to all models)
    var backendSettings: BackendSettings { get set }
    
    // Model management
    func getConfiguredModels() -> [ConfiguredAIModel]
    func addModel(_ config: ModelConfiguration) -> ConfiguredAIModel
    func removeModel(_ modelId: UUID) throws
    func updateModel(_ modelId: UUID, config: ModelConfiguration) throws
    
    // Capabilities
    func supportsModelAddition() -> Bool  // false for Apple Intelligence
    func supportsModelRemoval() -> Bool
    
    // Operations (delegated through models)
    func streamGenerate(
        modelId: UUID,
        prompt: String,
        context: AIContext
    ) -> AsyncThrowingStream<String, Error>
    
    func initialize() async throws
}
```

### BackendManager
Aggregates models from all backends and provides unified access.

```swift
@MainActor
class BackendManager: ObservableObject {
    static let shared = BackendManager()
    
    @Published private(set) var allModels: [ConfiguredAIModel] = []
    @Published var activeModel: ConfiguredAIModel?
    @Published private(set) var backends: [AIBackend] = []
    
    // Get all models from all backends
    func refreshModels() {
        allModels = backends.flatMap { $0.getConfiguredModels() }
    }
    
    // Model selection
    func selectModel(_ model: ConfiguredAIModel) {
        activeModel = model
        saveActiveModelId(model.id)
    }
    
    // Model management (delegates to backend)
    func addModel(to backendId: String, config: ModelConfiguration) throws {
        guard let backend = backends.first(where: { $0.id == backendId }) else {
            throw BackendError.backendNotFound
        }
        guard backend.supportsModelAddition() else {
            throw BackendError.operationNotSupported
        }
        let model = backend.addModel(config)
        refreshModels()
    }
    
    func removeModel(_ modelId: UUID) throws {
        guard let model = allModels.first(where: { $0.id == modelId }),
              let backend = model.backend else {
            throw BackendError.modelNotFound
        }
        try backend.removeModel(modelId)
        refreshModels()
    }
    
    // Stream generation (delegates to model's backend)
    func streamGenerate(prompt: String) -> AsyncThrowingStream<String, Error> {
        guard let model = activeModel,
              let backend = model.backend else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: BackendError.noActiveModel)
            }
        }
        return backend.streamGenerate(
            modelId: model.id,
            prompt: prompt,
            context: AIContext()
        )
    }
}
```

## Backend Implementations

### 1. Apple Foundation Models Backend
**Fixed Model Backend** - Single default model, cannot be modified.

```swift
@MainActor
@available(iOS 26.0, *)
class AppleFoundationBackend: AIBackend {
    let id = "apple-foundation"
    let name = "Apple Intelligence"
    let description = "On-device AI - Private and secure"
    let iconName = "apple.logo"
    
    private let defaultModelId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    
    func getConfiguredModels() -> [ConfiguredAIModel] {
        guard SystemLanguageModel.default.availability == .available else {
            return []
        }
        
        return [ConfiguredAIModel(
            id: defaultModelId,
            backendId: id,
            displayName: "Apple Intelligence",
            modelIdentifier: "apple-intelligence-default",
            configuration: ModelConfiguration(), // Empty config
            capabilities: ModelCapabilities(
                supportsStreaming: true,
                supportsVision: false,
                supportsFunctionCalling: false,
                maxContextLength: 8192,
                maxOutputTokens: 4096
            )
        )]
    }
    
    func supportsModelAddition() -> Bool { false }
    func supportsModelRemoval() -> Bool { false }
    
    func addModel(_ config: ModelConfiguration) -> ConfiguredAIModel {
        fatalError("Apple Foundation backend does not support adding models")
    }
    
    func removeModel(_ modelId: UUID) throws {
        throw BackendError.operationNotSupported
    }
}
```

### 2. OpenAI Compatible Backend
**Dynamic Model Backend** - Users can add/remove/configure multiple models.

```swift
@MainActor
class OpenAICompatibleBackend: AIBackend {
    let id = "openai-compatible"
    let name = "OpenAI Compatible"
    let description = "Connect to OpenAI, Ollama, or compatible APIs"
    let iconName = "cloud.fill"
    
    private var models: [ConfiguredAIModel] = []
    
    init() {
        loadModels()
    }
    
    func getConfiguredModels() -> [ConfiguredAIModel] {
        return models
    }
    
    func supportsModelAddition() -> Bool { true }
    func supportsModelRemoval() -> Bool { true }
    
    func addModel(_ config: ModelConfiguration) -> ConfiguredAIModel {
        let model = ConfiguredAIModel(
            id: UUID(),
            backendId: id,
            displayName: config.displayName ?? "Custom Model",
            modelIdentifier: config.modelIdentifier ?? "",
            configuration: config,
            capabilities: ModelCapabilities(
                supportsStreaming: true,
                supportsVision: false,
                supportsFunctionCalling: false,
                maxContextLength: 4096,
                maxOutputTokens: 2048
            )
        )
        models.append(model)
        saveModels()
        return model
    }
    
    func removeModel(_ modelId: UUID) throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        models.remove(at: index)
        saveModels()
    }
    
    func updateModel(_ modelId: UUID, config: ModelConfiguration) throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        models[index].configuration = config
        saveModels()
    }
    
    private func saveModels() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(models) {
            UserDefaults.standard.set(data, forKey: "openai_compatible_models")
        }
    }
    
    private func loadModels() {
        guard let data = UserDefaults.standard.data(forKey: "openai_compatible_models"),
              let loaded = try? JSONDecoder().decode([ConfiguredAIModel].self, from: data) else {
            return
        }
        models = loaded
    }
}
```

## User Workflows

### Add OpenAI Model
```
User Flow:
1. Settings > Models > Add Model
2. Select "OpenAI Compatible" backend
3. Fill form:
   - Display Name: "GPT-4 Turbo"
   - API URL: "https://api.openai.com/v1"
   - API Key: "sk-..."
   - Model ID: "gpt-4-turbo"
4. Save
5. Model appears in all model pickers

Code:
let config = ModelConfiguration(
    apiURL: "https://api.openai.com/v1",
    apiKey: "sk-...",
    modelIdentifier: "gpt-4-turbo"
)
try BackendManager.shared.addModel(to: "openai-compatible", config: config)
```

### Select Model in Chat
```
User Flow:
1. ChatView > Model Picker
2. See all models:
   - Apple Intelligence
   - GPT-4 Turbo
   - Claude 3 Sonnet
   - Llama 2 7B
3. Tap "GPT-4 Turbo"
4. Chat uses that model

Code:
BackendManager.shared.selectModel(gpt4Model)
```

### Use Selected Model
```swift
// User sends message
let stream = BackendManager.shared.streamGenerate(prompt: userMessage)
for try await chunk in stream {
    // Display chunk
}

// Backend manager automatically:
// 1. Gets activeModel
// 2. Gets model's backend
// 3. Calls backend.streamGenerate(modelId:prompt:context:)
```

## File Structure

```
OpenWebUI/
├── Services/
│   ├── BackendManager.swift              # Model aggregator
│   ├── Protocols/
│   │   ├── AIBackend.swift               # Backend protocol
│   │   └── AIBackendSettings.swift       # Backend settings
│   ├── Models/
│   │   ├── ConfiguredAIModel.swift       # Model + config
│   │   ├── ModelConfiguration.swift      # Model settings
│   │   └── ModelCapabilities.swift       # What model can do
│   └── Backends/
│       ├── AppleFoundationBackend.swift  # Fixed model
│       ├── OpenAICompatibleBackend.swift # Dynamic models
│       ├── LlamaCppBackend.swift         # Local GGUF
│       └── LiteRTBackend.swift           # TFLite models
└── Views/
    ├── Chat/
    │   └── ModelPickerView.swift         # Unified picker
    └── Settings/
        ├── ModelsView.swift              # Browse models
        └── AddModelView.swift            # Add/edit model
```

## Key Benefits

1. **User-Friendly**: Users select models, not technical backends
2. **Flexible**: Each model has independent configuration
3. **Extensible**: Easy to add models without changing code
4. **Unified**: All models work the same way in UI
5. **Persistent**: Model configurations saved per-backend

## Migration Notes

**Old**: User selected backend → backend listed models → user used model  
**New**: User directly selects model → model knows its backend → backend executes

This is a fundamental shift from backend-first to model-first UX.
