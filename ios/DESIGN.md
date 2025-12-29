# Open WebUI iOS - Design Document

## Overview

Open WebUI iOS is a native iOS application that provides a ChatGPT-like interface with support for multiple AI backends. The app follows a **model-centric architecture** where users interact with AI models rather than backends directly.

## Architecture Philosophy

### Model-Centric Design

Unlike traditional approaches where users select backends (OpenAI, Ollama, etc.), Open WebUI iOS adopts a model-centric approach:

- **Users select models**, not backends
- **Backends provide models** as their primary responsibility
- **Models encapsulate configuration** (API endpoints, keys, parameters)
- **BackendManager aggregates** all models from all backends

### Key Principles

1. **Single Responsibility**: Each component has one clear purpose
2. **Protocol-Oriented**: Behaviors defined through protocols for flexibility
3. **SwiftUI Native**: Modern SwiftUI patterns throughout
4. **Reactive**: @Published properties and Combine for state management
5. **Privacy-First**: On-device processing where possible (Apple Intelligence)

## Core Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐ │
│  │ ChatView│  │ModelsView│  │ Settings │  │NewChatView│ │
│  └────┬────┘  └────┬────┘  └─────┬────┘  └────┬─────┘ │
└───────┼───────────┼──────────────┼────────────┼────────┘
        │           │              │            │
        └───────────┴──────────────┴────────────┘
                           ▼
        ┌─────────────────────────────────────┐
        │       BackendManager (Singleton)     │
        │  • Aggregates all models             │
        │  • Manages active model selection    │
        │  • Routes generation requests        │
        └──────────────┬──────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
┌────────────────┐         ┌────────────────┐
│  AIBackend     │         │  AIBackend     │
│  (Protocol)    │         │  (Protocol)    │
└────────────────┘         └────────────────┘
         │                           │
         ▼                           ▼
┌────────────────┐         ┌────────────────┐
│ AppleFoundation│         │OpenAICompatible│
│   Backend      │         │    Backend     │
│                │         │                │
│ • Fixed Model  │         │ • Dynamic      │
│ • On-device    │         │ • User-config  │
└────────────────┘         └────────────────┘
```

## Component Details

### 1. BackendManager

**Purpose**: Central hub for model management and request routing

**Responsibilities**:
- Register and discover backends automatically
- Aggregate models from all backends
- Manage active model selection
- Route generation requests to appropriate backend
- Notify views of model changes

**Key Properties**:
```swift
@Published var allModels: [ConfiguredAIModel]
@Published var activeModel: ConfiguredAIModel?
var backends: [any AIBackend]
```

**Pattern**: Singleton with auto-discovery

### 2. AIBackend Protocol

**Purpose**: Define contract for backend implementations

**Core Methods**:
```swift
func getConfiguredModels() -> [ConfiguredAIModel]
func addModel(_ config: ModelConfiguration) throws -> ConfiguredAIModel
func removeModel(_ modelId: UUID) throws
func updateModel(_ modelId: UUID, config: ModelConfiguration) throws
func streamGenerate(modelId: UUID, prompt: String, context: AIContext) 
    -> AsyncThrowingStream<String, Error>
func supportsModelAddition() -> Bool
func supportsModelRemoval() -> Bool
```

**Auto-Registration**:
```swift
static let autoRegister: Void = {
    BackendManager.registerBackendFactory {
        MyBackend()
    }
}()
```

### 3. ConfiguredAIModel

**Purpose**: Represent a user-facing model instance

**Structure**:
```swift
struct ConfiguredAIModel {
    let id: UUID
    let backendId: String
    var displayName: String
    let modelIdentifier: String
    var configuration: ModelConfiguration
    let capabilities: ModelCapabilities
}
```

**Key Concept**: Each model is independent with its own configuration, even if multiple models use the same backend.

### 4. Backend Implementations

#### Apple Foundation Backend
- **Type**: Fixed model backend
- **Model Count**: 1 (system-provided)
- **User Actions**: Cannot add/remove models
- **Features**: On-device processing, privacy-first
- **Availability**: iOS 18.2+ with Apple Intelligence

#### OpenAI Compatible Backend
- **Type**: Dynamic model backend
- **Model Count**: Unlimited (user-configured)
- **User Actions**: Add/remove/update models
- **Configuration**: API URL, API key, organization ID
- **Persistence**: UserDefaults (JSON)
- **Use Cases**: OpenAI, Ollama, Groq, any OpenAI-compatible API

#### Llama.cpp Backend (Stub)
- **Type**: Local model backend
- **Planned Features**: GGUF model support
- **Status**: Interface defined, implementation pending

#### LiteRT Backend (Stub)
- **Type**: Local model backend
- **Planned Features**: TensorFlow Lite models
- **Status**: Interface defined, implementation pending

## Data Flow

### Model Selection Flow
```
User taps model → BackendManager.selectModel() → 
activeModel updated → UI updates via @Published
```

### Chat Generation Flow
```
User sends message → ChatViewModel.sendMessage() →
BackendManager.streamGenerate() →
Finds backend via model.backendId →
Backend.streamGenerate() →
Stream chunks back to UI
```

### Model Addition Flow
```
User opens Settings → Selects backend → Taps "Add Model" →
Fills configuration form → Backend.addModel() →
Backend persists + returns model →
BackendManager.refreshModels() →
Model appears in Models page
```

## UI Architecture

### View Organization

```
ContentView
├── TabView
│   ├── ChatsListView
│   │   └── ChatView (per chat)
│   │       ├── MessageView
│   │       ├── TypingIndicatorView
│   │       └── PerformanceInsightsView
│   │
│   ├── ModelsView
│   │   └── ModelRowWithBackend
│   │
│   └── SettingsView
│       ├── BackendSelectionView
│       │   ├── BackendRowWithModels
│       │   └── AddModelView
│       └── Other settings...
│
└── NewChatView (sheet)
```

### State Management

**Pattern**: MVVM with ObservableObject

**View Models**:
- `ChatViewModel`: Manages chat state and message generation
- `ChatsListViewModel`: Manages chat list
- `NewChatViewModel`: Handles new chat creation

**Shared State**:
- `BackendManager.shared`: Global model state
- `ChatStorage.shared`: Persistent chat storage

## Persistence

### Chat Storage
- **Location**: UserDefaults
- **Format**: JSON
- **Key**: `"chats"` and `"messages_{chatId}"`
- **Scope**: Per-device

### Model Configuration
- **Location**: UserDefaults (per backend)
- **Format**: JSON (Codable)
- **Key**: `"openai_compatible_models"` (example)
- **Restoration**: Automatic on backend initialization

## Design Patterns

### 1. Auto-Discovery Pattern

Backends register themselves automatically when their class is loaded:

```swift
static let autoRegister: Void = {
    BackendManager.registerBackendFactory { MyBackend() }
}()
```

No manual registration needed - just add the backend file to the project.

### 2. Protocol Extension Pattern

Default implementations for optional protocol methods:

```swift
extension AIBackend {
    func supportsModelAddition() -> Bool { false }
    func supportsModelRemoval() -> Bool { false }
}
```

### 3. Computed Property Pattern

Backend reference computed at runtime:

```swift
var backend: AIBackend? {
    BackendManager.shared.getBackend(id: backendId)
}
```

### 4. Publisher Pattern

Using Combine for reactive updates:

```swift
@Published var allModels: [ConfiguredAIModel] = []
objectWillChange.send() // Trigger UI update
```

## User Experience Flow

### First Launch
1. App opens to empty chat list
2. Welcome chat created automatically
3. Apple Intelligence model available (if supported)
4. User can add more models via Settings

### Adding a Model
1. Settings → Backends → Expand backend → "Add Model"
2. Fill form (display name, model ID, API URL, key)
3. Save → Model persists
4. Model appears in Models page
5. Can now select for chat

### Starting a Chat
1. Tap "+" to create new chat
2. Select model from list (all backends shown)
3. Optional: Add system prompt
4. Model selection saved with chat
5. Start conversation

### Switching Models
1. Go to Models page
2. Tap any model
3. Model becomes active
4. Used for new messages in all chats

## Error Handling

### Backend Errors
```swift
enum BackendError: LocalizedError {
    case notInitialized
    case notAvailable
    case modelNotFound
    case invalidConfiguration(String)
    case operationNotSupported
}
```

### User-Facing Messages
- Configuration errors: Show alert with specific issue
- Network errors: Show retry option
- Model unavailable: Suggest checking settings

## Performance Considerations

### Lazy Loading
- Messages loaded on-demand per chat
- Models loaded once at startup
- Streaming reduces memory for long responses

### Memory Management
- Weak references where appropriate
- Dispose of streams properly
- Clear old messages when needed

### Responsiveness
- Async/await for all network operations
- Main actor isolation for UI updates
- Background processing for large operations

## Security & Privacy

### API Keys
- Stored in UserDefaults (encrypted by iOS)
- Never logged or printed
- Cleared when model removed

### On-Device Processing
- Apple Intelligence runs 100% on-device
- No data sent to Apple servers
- Chat history stays local

### Data Storage
- All data in app sandbox
- Removed when app deleted
- No iCloud sync (yet)

## Future Considerations

### Planned Features
1. **Llama.cpp Integration**: Local GGUF model support
2. **LiteRT Integration**: TensorFlow Lite models
3. **RAG Support**: Document-based context
4. **Function Calling**: Tool use support
5. **Vision Models**: Image input support
6. **iCloud Sync**: Cross-device chat history

### Extensibility Points
- New backends: Implement `AIBackend` protocol
- New model types: Extend `ModelCapabilities`
- Custom storage: Replace `ChatStorage`
- Plugin system: Future dynamic loading

## Testing Strategy

### Unit Tests
- Backend functionality
- Model management
- Configuration persistence

### Integration Tests
- End-to-end chat flow
- Model switching
- Error scenarios

### UI Tests
- Navigation flows
- Form validation
- Settings changes

## Code Style

### Swift Conventions
- Swift 6 language mode
- Strict concurrency checking
- Actor isolation where appropriate
- Protocol-oriented design

### Naming
- Clear, descriptive names
- Avoid abbreviations
- Consistent terminology

### Documentation
- DocC comments for public APIs
- Inline comments for complex logic
- Architecture docs (this file)

## Conclusion

Open WebUI iOS is built on a flexible, extensible architecture that prioritizes user experience and privacy. The model-centric design makes it easy to work with multiple AI services while maintaining a clean, intuitive interface. The protocol-based backend system allows for easy addition of new AI providers without modifying existing code.
