# Apple Intelligence Integration Guide

## Overview

This document explains how the Open WebUI iOS app integrates Apple's on-device Large Language Model using the FoundationModels framework introduced in iOS 18.

## Architecture

### FoundationModels Framework

The FoundationModels framework provides access to Apple's on-device LLM without requiring API keys or internet connectivity. Key components:

- **SystemLanguageModel**: Entry point for accessing the default on-device model
- **LanguageModelSession**: Manages conversation context and history
- **Streaming & Atomic Generation**: Supports both real-time and batch inference

## Implementation

### 1. Service Layer (`MLXService.swift`)

The `MLXService` class wraps Apple Intelligence functionality:

```swift
import FoundationModels

@MainActor
class MLXService: ObservableObject {
    // Session management - each chat has its own context
    private var sessions: [String: LanguageModelSession] = [:]
    
    @Published var isModelAvailable: Bool = false
    @Published var modelStatus: ModelAvailabilityStatus = .checking
}
```

### 2. Availability Check

Always check model availability before use:

```swift
func checkAvailability() async {
    let model = SystemLanguageModel.default
    
    switch model.availability {
    case .available:
        self.isModelAvailable = true
        
    case .unavailable(let reason):
        // Handle: .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady
        self.isModelAvailable = false
    }
}
```

### 3. Session Management

Each chat conversation maintains its own session for context:

```swift
private func getSession(for chatId: String, systemPrompt: String?) -> LanguageModelSession? {
    if let existingSession = sessions[chatId] {
        return existingSession
    }
    
    // Create new session with system prompt
    let session = LanguageModelSession(
        model: .default,
        instructions: systemPrompt ?? defaultPrompt
    )
    
    sessions[chatId] = session
    return session
}
```

### 4. Streaming Generation

For real-time chat interfaces:

```swift
func streamGenerate(prompt: String, chatId: String) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task { @MainActor in
            guard let session = getSession(for: chatId, systemPrompt: nil) else {
                continuation.finish(throwing: MLXServiceError.sessionCreationFailed)
                return
            }
            
            let stream = session.streamResponse(to: prompt)
            
            for try await part in stream {
                continuation.yield(part.content)
            }
            
            continuation.finish()
        }
    }
}
```

### 5. Atomic Generation

For background tasks like summarization:

```swift
func generate(prompt: String, chatId: String? = nil) async throws -> String {
    guard let session = getSession(for: chatId ?? UUID().uuidString, systemPrompt: nil) else {
        throw MLXServiceError.sessionCreationFailed
    }
    
    let response = try await session.respond(to: prompt)
    return response.content
}
```

## Integration with Chat System

### Chat View Model

The `ChatViewModel` uses `MLXService` for local inference:

```swift
@MainActor
class ChatViewModel: ObservableObject {
    private let mlxService = MLXService.shared
    
    func sendMessage(_ content: String) async {
        // Determine if we should use local or cloud
        if shouldUseLocalInference() {
            // Use Apple Intelligence
            for try await chunk in mlxService.streamGenerate(
                prompt: content,
                chatId: chat.id
            ) {
                updateAssistantMessage(with: chunk)
            }
        } else {
            // Use OpenAI/Ollama
            // ... cloud inference code
        }
    }
    
    private func shouldUseLocalInference() -> Bool {
        // Check if offline mode is enabled or if using Apple Intelligence model
        return AppConfig.enableOfflineMode && mlxService.isModelAvailable
    }
}
```

## Context Management

### Conversation History

The `LanguageModelSession` automatically maintains conversation history. To clear:

```swift
// Clear specific chat session
mlxService.clearSession(for: chatId)

// Clear all sessions
mlxService.clearAllSessions()
```

### System Prompts

Set the system prompt when creating a session:

```swift
let systemPrompt = """
You are a helpful AI assistant specializing in \(domain).
Be concise and accurate in your responses.
"""

let session = LanguageModelSession(
    model: .default,
    instructions: systemPrompt
)
```

## Error Handling

### Common Errors

1. **Model Not Available**
   - Device not eligible (older devices)
   - Apple Intelligence not enabled
   - Model still downloading

2. **Context Window Exceeded**
   - Clear session history
   - Start new session

3. **Safety Guardrails**
   - Request violates content policy
   - Handle gracefully with user message

### Implementation

```swift
do {
    let response = try await mlxService.generate(prompt: userInput, chatId: chatId)
    // Handle success
} catch MLXServiceError.modelNotAvailable {
    // Show settings prompt
    showAppleIntelligenceSettings()
} catch MLXServiceError.inferenceFailed(let error) {
    // Show error message
    showError(error)
}
```

## Best Practices

### 1. Check Availability Early

Check model availability when the app launches and when entering chat view:

```swift
.onAppear {
    Task {
        await mlxService.checkAvailability()
    }
}
```

### 2. Provide Fallbacks

Always have a fallback to cloud models:

```swift
if mlxService.isModelAvailable {
    // Use Apple Intelligence
} else {
    // Use OpenAI or Ollama
}
```

### 3. Session Management

- Create one session per chat conversation
- Clear sessions when chats are deleted
- Don't create unnecessary sessions

### 4. User Communication

Clearly communicate when using on-device vs. cloud:

```swift
if isUsingLocalModel {
    statusLabel = "🍎 Apple Intelligence (On-Device)"
} else {
    statusLabel = "☁️ Cloud Model"
}
```

## Testing

### Simulator Limitations

Apple Intelligence is **not available** in the iOS Simulator. You must test on:
- Physical iPhone 15 Pro or later
- Physical iPad with M1 chip or later

### Enabling in Settings

Before testing:
1. Settings > Apple Intelligence & Siri
2. Enable Apple Intelligence
3. Wait for model download (can take several minutes)
4. Restart the app

### Test Cases

1. **Availability Check**
   - Test with AI enabled
   - Test with AI disabled
   - Test on unsupported device

2. **Generation**
   - Test streaming responses
   - Test atomic responses
   - Test with long conversations (context)

3. **Error Handling**
   - Test with model unavailable
   - Test context overflow
   - Test network transitions

## Performance Considerations

### Device Requirements

Apple Intelligence requires significant compute power:
- **Minimum**: iPhone 15 Pro, iPad (M1)
- **Recommended**: iPhone 16 Pro, iPad (M2+)

### Battery Impact

On-device inference uses the Neural Engine, which is power-efficient, but:
- Monitor battery usage in long sessions
- Consider providing battery warnings
- Allow users to switch to cloud in low-battery situations

### Response Time

- **First Response**: 1-3 seconds (model loading)
- **Subsequent**: 100-500ms per token
- **Faster than**: Most cloud APIs (no network latency)

## Privacy Considerations

### Data Handling

Apple Intelligence runs **entirely on-device**:
- ✅ No data sent to servers
- ✅ No API keys required
- ✅ No user tracking
- ✅ Conversation history stays local

### User Transparency

Communicate privacy benefits:
```swift
Text("🔒 Your conversation stays on your device")
    .font(.caption)
    .foregroundStyle(.secondary)
```

## Future Enhancements

### Potential Improvements

1. **Custom Models**: When Apple allows fine-tuning
2. **Multi-Modal**: Image understanding capabilities
3. **Tool Calling**: If Apple adds function calling support
4. **Embeddings**: For local RAG if APIs become available

### Monitoring Apple Updates

Watch for:
- iOS 18.x updates with new FoundationModels APIs
- WWDC announcements
- Apple Intelligence feature additions

## Resources

### Documentation
- Apple Developer Documentation: FoundationModels framework
- WWDC Sessions on Apple Intelligence
- iOS 18 Release Notes

### Code References
- `MLXService.swift`: Main service implementation
- `ChatViewModel.swift`: Integration with chat system
- Reference documentation in this project

## Support

For issues with Apple Intelligence integration:
1. Check device compatibility
2. Verify iOS 18+ installed
3. Confirm Apple Intelligence is enabled
4. Review error logs in Xcode console
5. Open GitHub issue with details

---

**Note**: This integration is designed to be future-proof as Apple continues to enhance the FoundationModels framework. The architecture allows for easy updates when new capabilities are released.
