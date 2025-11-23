# Open WebUI iOS - Project Overview

## Executive Summary

This document provides a comprehensive overview of the Open WebUI iOS application - a native iOS implementation that clones all functionality from the Open WebUI web application with the addition of Apple's on-device AI capabilities.

## Project Goals

### Primary Objectives
1. **Feature Parity**: Match all core functionalities of the web application
2. **Code Equivalence**: Maintain identical business logic and API contracts
3. **Native Experience**: Provide a polished, native iOS user experience
4. **Offline First**: Enable full functionality with Apple's on-device AI
5. **Privacy Focused**: Keep user data on-device when possible

### Key Differentiators
- **Apple Intelligence Integration**: On-device LLM inference without API keys
- **Native Performance**: Optimized for iOS with native frameworks
- **Seamless Sync**: Compatible with existing Open WebUI backend
- **Privacy by Default**: Local processing when using Apple Intelligence

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     SwiftUI Views                        │
│  (LoginView, ChatView, ModelsView, DocumentsView, etc.)  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                     View Models                          │
│     (ChatViewModel, ModelsViewModel, etc.)               │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  Service Layer                           │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ APIClient   │  │ AuthService  │  │ MLXService     │ │
│  │             │  │              │  │ (Apple Intel.) │ │
│  └─────────────┘  └──────────────┘  └────────────────┘ │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │OpenAIService│  │OllamaService │  │ RAGService     │ │
│  └─────────────┘  └──────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│            Backend APIs / Local Storage                  │
│  ┌──────────────┐  ┌─────────────────┐  ┌────────────┐ │
│  │ Open WebUI   │  │ Apple            │  │  Keychain  │ │
│  │ Backend API  │  │ FoundationModels │  │            │ │
│  └──────────────┘  └─────────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Design Patterns

#### 1. MVVM (Model-View-ViewModel)
- **Models**: Data structures matching backend API
- **Views**: SwiftUI views for UI rendering
- **ViewModels**: Business logic and state management

#### 2. Service Layer Pattern
- Encapsulates external dependencies
- Provides clean API for ViewModels
- Handles error recovery and retries
- Manages authentication tokens

#### 3. Repository Pattern (Implicit)
- Services act as repositories
- Abstract data source details
- Enable easy testing with mocks

#### 4. Singleton Pattern
- Shared services (`MLXService.shared`, `APIClient.shared`)
- Ensures single point of configuration
- Manages global state

## Core Components

### 1. App Entry Point (`OpenWebUIApp.swift`)

```swift
@main
struct OpenWebUIApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
```

**Responsibilities**:
- App lifecycle management
- Root view selection based on auth state
- Global app state initialization

### 2. Service Layer

#### APIClient
- **Purpose**: Core HTTP networking
- **Features**: 
  - Request building with auth tokens
  - Response parsing and error handling
  - Streaming support for SSE
  - File upload capabilities

#### AuthService
- **Purpose**: User authentication
- **Features**:
  - Login/signup flows
  - Token management via Keychain
  - Auto-login on app launch
  - Token refresh

#### MLXService (Apple Intelligence)
- **Purpose**: On-device AI inference
- **Features**:
  - Model availability checking
  - Session-based context management
  - Streaming and atomic generation
  - Multi-chat support

#### OpenAIService
- **Purpose**: OpenAI API integration
- **Features**:
  - Chat completions
  - Streaming responses
  - Embeddings generation
  - Model listing

#### OllamaService
- **Purpose**: Ollama API integration
- **Features**:
  - Local model management
  - Generate and chat endpoints
  - Model pulling/deletion
  - Progress tracking

#### RAGService
- **Purpose**: Document management and retrieval
- **Features**:
  - Document upload/download
  - Knowledge base management
  - Query with context
  - Local document processing

#### ToolService
- **Purpose**: Function calling
- **Features**:
  - Tool registration
  - Tool execution
  - Function call parsing
  - Result formatting

### 3. Data Models

#### API Models (`APIModels.swift`)
```swift
struct User: Codable, Identifiable
struct Model: Codable, Identifiable
struct Message: Codable, Identifiable
struct ChatCompletionRequest: Codable
struct Tool: Codable, Identifiable
struct Document: Codable, Identifiable
```

#### Chat Models (`ChatModels.swift`)
```swift
struct Chat: Codable, Identifiable
class ChatSession: ObservableObject
struct ConversationContext
```

### 4. User Interface

#### Navigation Structure
```
TabView
├── ChatsListView (Chat History)
├── ModelsView (Model Management)
├── DocumentsView (RAG Documents)
└── SettingsView (App Settings)
```

#### Key Views

**LoginView**
- Email/password authentication
- Sign up flow
- Error handling

**ChatView**
- Message list with auto-scroll
- Text input with multi-line support
- Streaming indicator
- Model selection

**ModelsView**
- Cloud models listing
- Local models display
- Model status indicators

**DocumentsView**
- Document list with metadata
- Upload via native file picker
- Delete with swipe action

**SettingsView**
- User profile
- Backend configuration
- Model defaults
- Feature toggles

## Feature Implementation Status

### ✅ Fully Implemented

#### Authentication & User Management
- Login with email/password
- Sign up with validation
- Token storage in Keychain
- Auto-login
- Logout functionality

#### Chat System
- Create new chats
- List all chats with metadata
- Real-time streaming responses
- Message history
- Delete chats
- Context preservation

#### Apple Intelligence
- Model availability checking
- Session management per chat
- Streaming generation
- Atomic generation
- Status monitoring
- Error handling

#### Model Management
- List cloud models (OpenAI)
- Display local models
- Model metadata display
- Provider organization

#### Document Management (RAG)
- Upload documents
- List with metadata
- Delete documents
- File type detection
- Backend API integration

#### Settings
- User profile display
- Backend URL configuration
- Model parameter defaults
- Feature status display
- Cache management

### 🚧 Partially Implemented

#### RAG Pipeline
- ✅ Document upload/list/delete
- ✅ Backend integration
- ⏳ Local embedding generation
- ⏳ Vector database integration
- ⏳ Query with context

#### Tool Calling
- ✅ Tool service structure
- ✅ Backend API integration
- ⏳ Tool execution UI
- ⏳ Function call handling
- ⏳ Result display

#### Ollama Integration
- ✅ Service implementation
- ✅ API models
- ⏳ Model pulling UI
- ⏳ Progress tracking
- ⏳ Testing and validation

### 📋 Planned

#### Image Generation
- DALL-E integration
- Image display in chat
- Image saving
- Progress indicators

#### Audio Features
- Voice input
- Speech-to-text
- Text-to-speech
- Audio playback

#### Advanced UI
- iPad optimization
- Dark mode refinements
- Accessibility features
- Haptic feedback

#### Extensions
- Share extension
- Widget support
- Siri shortcuts
- Spotlight integration

## Technical Stack

### Languages & Frameworks
- **Swift 5.9+**: Primary language
- **SwiftUI**: UI framework
- **FoundationModels**: Apple Intelligence (iOS 18+)
- **Combine**: Reactive programming
- **Foundation**: Core utilities

### Dependencies (via Swift Package Manager)
- **Alamofire**: Advanced networking
- **Starscream**: WebSocket support
- **MarkdownUI**: Markdown rendering
- **KeychainAccess**: Secure storage

### Apple Frameworks
- **Foundation**: Core functionality
- **SwiftUI**: UI components
- **Combine**: Data flow
- **Security**: Keychain access
- **UniformTypeIdentifiers**: File handling
- **FoundationModels**: On-device AI

## Code Organization

### Directory Structure
```
ios/
├── OpenWebUI/                    # Main application code
│   ├── App/                      # App lifecycle and config
│   ├── Models/                   # Data models
│   ├── Services/                 # Business logic services
│   ├── ViewModels/               # View state management
│   ├── Views/                    # SwiftUI views
│   │   ├── Chat/                 # Chat-related views
│   │   ├── Models/               # Model management
│   │   ├── Documents/            # Document management
│   │   └── Settings/             # Settings views
│   ├── Utilities/                # Helper functions
│   └── Resources/                # Assets and config files
├── OpenWebUITests/               # Unit tests
├── OpenWebUIUITests/             # UI tests
├── Package.swift                 # Dependencies
├── README.md                     # Project overview
├── SETUP.md                      # Build instructions
├── APPLE_INTELLIGENCE_INTEGRATION.md  # AI docs
└── .gitignore                    # Git ignore rules
```

### Naming Conventions

#### Files
- Views: `<Name>View.swift` (e.g., `ChatView.swift`)
- ViewModels: `<Name>ViewModel.swift`
- Services: `<Name>Service.swift`
- Models: `<Name>Models.swift`

#### Classes/Structs
- PascalCase for types
- camelCase for properties/methods
- Descriptive names

#### SwiftUI Views
```swift
struct ChatView: View {
    var body: some View {
        // Implementation
    }
}
```

#### Services
```swift
class ChatService {
    static let shared = ChatService()
    private init() {}
}
```

## API Compatibility

### Backend Endpoints Used

```
Authentication:
POST   /api/auths/signin
POST   /api/auths/signup
GET    /api/auths/me

Chats:
GET    /api/chats
POST   /api/chats
GET    /api/chats/{id}
DELETE /api/chats/{id}
GET    /api/chats/{id}/messages

Models:
GET    /api/models
GET    /openai/v1/models
GET    /ollama/api/tags

OpenAI:
POST   /openai/v1/chat/completions
POST   /openai/v1/embeddings

Ollama:
POST   /ollama/api/generate
POST   /ollama/api/chat
POST   /ollama/api/pull
DELETE /ollama/api/delete

RAG:
POST   /api/retrieval/upload
GET    /api/retrieval/documents
GET    /api/retrieval/documents/{id}
DELETE /api/retrieval/documents/{id}
POST   /api/retrieval/query

Knowledge Base:
GET    /api/knowledge
POST   /api/knowledge
GET    /api/knowledge/{id}
PUT    /api/knowledge/{id}
DELETE /api/knowledge/{id}

Tools:
GET    /api/tools
GET    /api/tools/{id}
POST   /api/tools
PUT    /api/tools/{id}
DELETE /api/tools/{id}
POST   /api/tools/execute
```

### Request/Response Format

All API communication uses JSON with snake_case keys:
```json
{
  "user_id": "123",
  "created_at": "2024-01-01T00:00:00Z",
  "model_ids": ["gpt-4"]
}
```

Swift models use camelCase with `CodingKeys`:
```swift
struct Chat: Codable {
    let userId: String
    let createdAt: Date
    let modelIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case createdAt = "created_at"
        case modelIds = "model_ids"
    }
}
```

## Testing Strategy

### Unit Tests
- Service layer methods
- Model encoding/decoding
- Business logic
- Utility functions

### Integration Tests
- API client requests
- Authentication flows
- Data persistence
- Service interactions

### UI Tests
- Navigation flows
- Form validation
- User interactions
- Error states

### Manual Testing Checklist
- [ ] Login/logout flows
- [ ] Chat creation and streaming
- [ ] Model switching
- [ ] Document upload
- [ ] Apple Intelligence availability
- [ ] Offline mode
- [ ] Error handling
- [ ] Memory leaks (Instruments)

## Performance Considerations

### Memory Management
- Use `weak` references in closures
- Clear sessions when chats deleted
- Limit message history cache
- Release resources in `deinit`

### Network Optimization
- Use URLCache for responses
- Implement request cancellation
- Batch operations when possible
- Compress large payloads

### UI Performance
- Use `LazyVStack` for long lists
- Implement pagination
- Debounce search input
- Cache computed properties

### Apple Intelligence
- Check availability once on launch
- Reuse sessions per chat
- Clear old sessions periodically
- Monitor memory usage

## Security Considerations

### Data Protection
- Store tokens in Keychain
- Use HTTPS for all API calls
- Validate SSL certificates
- Clear sensitive data on logout

### User Privacy
- On-device processing with Apple Intelligence
- No tracking or analytics
- User controls data sharing
- Transparent privacy policy

### Code Security
- No hardcoded secrets
- Validate all inputs
- Sanitize user content
- Handle errors gracefully

## Deployment

### Requirements
- Apple Developer Account
- Code signing certificate
- Provisioning profile
- App Store Connect access

### Build Configurations
- **Debug**: Local development
- **Release**: Production builds
- **TestFlight**: Beta testing

### Distribution Channels
- TestFlight for beta testing
- App Store for public release
- Enterprise distribution (optional)

## Future Roadmap

### Phase 2: Enhanced Features (1-2 months)
- Complete RAG implementation
- Tool calling UI
- Image generation
- Audio features
- Improved error handling

### Phase 3: Platform Expansion (2-3 months)
- iPad optimization
- macOS Catalyst version
- watchOS companion
- Widget support

### Phase 4: Advanced AI (3-6 months)
- Multi-modal support
- Custom model fine-tuning (if available)
- Advanced RAG techniques
- AI-powered features

## Contributing

See main repository CONTRIBUTING.md for guidelines.

### iOS-Specific Guidelines
- Follow Swift API Design Guidelines
- Use SwiftLint for consistency
- Write tests for new features
- Update documentation
- Test on physical devices

## Support & Resources

### Documentation
- README.md: Overview
- SETUP.md: Build guide
- APPLE_INTELLIGENCE_INTEGRATION.md: AI integration

### External Resources
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [FoundationModels Reference](https://developer.apple.com/documentation/foundationmodels)

### Community
- GitHub Issues: Bug reports
- Discussions: Feature requests
- Discord: Real-time chat

## License

Same as Open WebUI main project. See LICENSE file.

---

**Document Version**: 1.0
**Last Updated**: 2024
**Maintainer**: Open WebUI iOS Team
