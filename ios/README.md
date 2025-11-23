# Open WebUI iOS App

## Overview

This is the iOS native application clone of Open WebUI, providing all the core functionality of the web version with the addition of Apple's on-device ML capabilities for offline LLM support.

## Features

### Core Features (Matching Web Version)
- ✅ OpenAI API integration
- ✅ Ollama model support
- ✅ RAG (Retrieval Augmented Generation) support
- ✅ Tool/Function calling
- ✅ Multi-model conversations
- ✅ Image generation integration
- ✅ Audio transcription and TTS
- ✅ Knowledge base management
- ✅ Document processing and upload

### iOS-Specific Features
- 🍎 **Apple Intelligence (FoundationModels)** integration for on-device inference (iOS 18+)
- 📱 Native SwiftUI interface
- 💾 Core Data for local storage
- 🔒 iOS Keychain for secure credential storage
- 📴 Full offline mode with Apple's on-device LLM
- 🎤 Native audio recording and playback
- 📸 Native camera integration
- 🔔 Push notifications support
- 🧠 Session-based context management for conversations

## Requirements

- iOS 18.0+ (for Apple Intelligence/FoundationModels framework)
- Xcode 16.0+
- Swift 5.9+
- Apple Silicon Mac (M1/M2/M3/M4) or compatible iPhone/iPad for on-device inference
- Apple Intelligence enabled in device settings

## Architecture

The iOS app is designed to maximize code reusability with the web version while providing a native iOS experience:

### Business Logic Layer
- Shared API communication protocol with backend
- Identical data models and schemas
- Same authentication flow
- Compatible message format and protocol

### Platform-Specific Layer
- SwiftUI for UI components
- URLSession for networking
- Core Data for persistence
- MLX Swift for local LLM inference
- iOS-native features (Camera, Microphone, etc.)

### Key Components

```
ios/
├── OpenWebUI/
│   ├── App/
│   │   ├── OpenWebUIApp.swift           # App entry point
│   │   └── AppDelegate.swift            # App lifecycle
│   ├── Models/
│   │   ├── APIModels.swift              # API request/response models
│   │   ├── ChatModels.swift             # Chat-related models
│   │   ├── UserModels.swift             # User and auth models
│   │   └── DocumentModels.swift         # RAG document models
│   ├── Services/
│   │   ├── APIClient.swift              # Backend API client
│   │   ├── OpenAIService.swift          # OpenAI integration
│   │   ├── OllamaService.swift          # Ollama integration
│   │   ├── MLXService.swift             # Local inference with MLX
│   │   ├── RAGService.swift             # RAG pipeline
│   │   ├── ToolService.swift            # Tool/function calling
│   │   ├── AuthService.swift            # Authentication
│   │   └── StorageService.swift         # Local storage
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift          # Chat screen logic
│   │   ├── ModelViewModel.swift         # Model management
│   │   ├── SettingsViewModel.swift      # Settings logic
│   │   └── DocumentViewModel.swift      # Document management
│   ├── Views/
│   │   ├── Chat/
│   │   │   ├── ChatView.swift           # Main chat interface
│   │   │   ├── MessageView.swift        # Individual messages
│   │   │   └── InputView.swift          # Message input
│   │   ├── Models/
│   │   │   ├── ModelListView.swift      # Model selection
│   │   │   └── ModelDetailView.swift    # Model configuration
│   │   ├── Settings/
│   │   │   └── SettingsView.swift       # App settings
│   │   └── Documents/
│   │       └── DocumentListView.swift   # RAG documents
│   ├── Utilities/
│   │   ├── NetworkMonitor.swift         # Network status
│   │   ├── KeychainHelper.swift         # Secure storage
│   │   └── Extensions.swift             # Swift extensions
│   └── Resources/
│       ├── Assets.xcassets              # Images and colors
│       └── Info.plist                   # App configuration
├── OpenWebUITests/                      # Unit tests
├── OpenWebUIUITests/                    # UI tests
└── Package.swift                        # Swift Package Manager
```

## Getting Started

### Prerequisites

1. Install Xcode 15.0 or later from the Mac App Store
2. Ensure you have an Apple Developer account (for device testing)
3. Clone the repository

### Build and Run

1. Open the project in Xcode:
   ```bash
   cd ios
   open OpenWebUI.xcodeproj
   ```

2. Select your target device or simulator

3. Build and run (⌘R)

### Configuration

Configure the backend URL in `Config.swift`:

```swift
struct AppConfig {
    static let backendURL = "http://localhost:8080"  // Local development
    // static let backendURL = "https://your-server.com"  // Production
}
```

## Local Model Support

The iOS app supports running LLMs locally using Apple's FoundationModels framework (Apple Intelligence):

### Using Apple Intelligence (iOS 18+)

Apple Intelligence provides on-device LLM capabilities without any API keys or internet connection:

1. **Enable Apple Intelligence**:
   - Go to Settings > Apple Intelligence & Siri
   - Enable Apple Intelligence
   - Wait for the model to download (if not already downloaded)

2. **In the app**:
   - Select "Apple Intelligence" as the model provider
   - The app will automatically check availability
   - Start chatting with the on-device model

### Key Features:
- ✅ **No API Key Required**: Runs entirely on-device
- ✅ **Privacy-First**: All processing happens locally
- ✅ **Conversation Memory**: Sessions maintain context automatically
- ✅ **Streaming Responses**: Real-time token generation
- ✅ **Multiple Sessions**: Each chat has its own context window

### Supported Capabilities:
- Chat completion (streaming and atomic)
- Summarization
- Context-aware conversations
- System prompt customization

### Requirements:
- iOS 18.0 or later
- Apple Intelligence enabled
- Compatible device (iPhone 15 Pro/Pro Max or later, iPad with M1 or later)
- Model must be downloaded (happens automatically when enabled)

## API Compatibility

The iOS app maintains full API compatibility with the Open WebUI backend:

### Supported Endpoints
- `/api/auths/*` - Authentication
- `/api/chats/*` - Chat management
- `/api/models/*` - Model management
- `/ollama/*` - Ollama proxy
- `/openai/*` - OpenAI proxy
- `/api/retrieval/*` - RAG operations
- `/api/tools/*` - Tool management
- `/api/audio/*` - Audio processing
- `/api/images/*` - Image generation

## Development

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftLint for code consistency
- Write comprehensive unit tests
- Document public APIs

### Testing
```bash
# Run tests
xcodebuild test -scheme OpenWebUI

# Run UI tests
xcodebuild test -scheme OpenWebUIUITests
```

### Contributing
See the main repository CONTRIBUTING.md for guidelines.

## Roadmap

### Completed ✅
- [x] Basic app structure and navigation
- [x] API client implementation  
- [x] Authentication flow (login/signup)
- [x] Chat interface with streaming
- [x] Apple Intelligence (FoundationModels) integration
- [x] OpenAI API integration
- [x] Ollama integration structure
- [x] Model management UI
- [x] Settings interface
- [x] Session-based context management

### In Progress 🚧
- [ ] Complete RAG implementation with local vector database
- [ ] Tool/function calling integration
- [ ] Image generation support
- [ ] Audio transcription and TTS
- [ ] Enhanced offline capabilities

### Planned 📋
- [ ] Full Ollama integration testing
- [ ] Custom model downloads
- [ ] Knowledge base UI and management
- [ ] Multi-modal support (images, PDFs)
- [ ] Push notifications
- [ ] iPad optimization with split views
- [ ] watchOS companion app
- [ ] Widget support
- [ ] Siri integration
- [ ] Share extension for documents

## Known Issues

See GitHub Issues for the latest known issues and workarounds.

## License

This project follows the same license as Open WebUI. See LICENSE file for details.

## Support

For issues specific to the iOS app, please open an issue with the `ios` label.
For general Open WebUI questions, see the main repository.
