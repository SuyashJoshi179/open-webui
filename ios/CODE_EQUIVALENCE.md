# Code Equivalence Strategy

## Overview

This document explains how the iOS app maintains code equivalence with the Open WebUI web application, ensuring consistent behavior and easy maintainability across platforms.

## Design Principles

### 1. Shared Business Logic
The iOS app replicates the exact same business logic as the web application, just with platform-specific implementation:

**Web (JavaScript/Svelte)**:
```javascript
async function sendMessage(chatId, content) {
    const response = await fetch('/api/chats/messages', {
        method: 'POST',
        body: JSON.stringify({ chatId, content })
    });
    return response.json();
}
```

**iOS (Swift)**:
```swift
func sendMessage(chatId: String, content: String) async throws -> Message {
    return try await apiClient.request(
        path: "/api/chats/messages",
        method: "POST",
        body: ["chatId": chatId, "content": content]
    )
}
```

### 2. Identical API Contracts
Both platforms use the same backend API with identical:
- Endpoint paths
- Request/response formats
- Authentication mechanisms
- Error codes

### 3. Consistent Data Models
Data structures match 1:1 between platforms:

**Backend (Python)**:
```python
class Chat(BaseModel):
    id: str
    user_id: str
    title: str
    model_ids: List[str]
    created_at: datetime
    updated_at: datetime
```

**iOS (Swift)**:
```swift
struct Chat: Codable {
    let id: String
    let userId: String
    let title: String
    let modelIds: [String]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case modelIds = "model_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

## Feature Mapping

### Authentication Flow

#### Web Implementation
1. User enters credentials
2. POST to `/api/auths/signin`
3. Store token in localStorage
4. Set auth header for future requests

#### iOS Implementation
1. User enters credentials
2. POST to `/api/auths/signin` (identical endpoint)
3. Store token in Keychain (platform-specific, but same concept)
4. Set auth header for future requests (identical)

**Code Equivalence**: ✅ Same flow, same API, different storage mechanism

### Chat Management

#### Web Implementation
```javascript
// List chats
const chats = await fetchChats();

// Create chat
const newChat = await createChat({
    title: "New Chat",
    modelIds: ["gpt-4"]
});

// Delete chat
await deleteChat(chatId);
```

#### iOS Implementation
```swift
// List chats
let chats = try await apiClient.request(path: "/api/chats")

// Create chat
let newChat = try await apiClient.request(
    path: "/api/chats",
    method: "POST",
    body: CreateChatRequest(title: "New Chat", modelIds: ["gpt-4"])
)

// Delete chat
try await apiClient.request(path: "/api/chats/\(chatId)", method: "DELETE")
```

**Code Equivalence**: ✅ Identical API calls and flow

### Streaming Responses

#### Web Implementation
```javascript
const response = await fetch('/openai/v1/chat/completions', {
    method: 'POST',
    body: JSON.stringify({ stream: true, messages })
});

const reader = response.body.getReader();
while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    const text = new TextDecoder().decode(value);
    handleStreamChunk(text);
}
```

#### iOS Implementation
```swift
let stream = apiClient.stream(
    path: "/openai/v1/chat/completions",
    method: "POST",
    body: request
)

for try await chunk in stream {
    handleStreamChunk(chunk)
}
```

**Code Equivalence**: ✅ Same streaming protocol (SSE), different platform API

### RAG Document Upload

#### Web Implementation
```javascript
const formData = new FormData();
formData.append('file', file);

const response = await fetch('/api/retrieval/upload', {
    method: 'POST',
    body: formData
});
```

#### iOS Implementation
```swift
let document = try await ragService.uploadDocument(fileURL: fileURL)
// Internally uses same multipart/form-data format
```

**Code Equivalence**: ✅ Same multipart upload, same endpoint

## Service Layer Equivalence

### Backend Router Structure
```
backend/open_webui/routers/
├── auths.py          → AuthService (iOS)
├── chats.py          → ChatService (iOS)
├── openai.py         → OpenAIService (iOS)
├── ollama.py         → OllamaService (iOS)
├── retrieval.py      → RAGService (iOS)
├── tools.py          → ToolService (iOS)
└── ...
```

Each iOS service corresponds to a backend router, implementing the same operations.

### Example: Model Management

**Backend (routers/models.py)**:
```python
@router.get("/api/models")
async def get_models():
    return {"data": models}

@router.get("/api/models/{id}")
async def get_model(id: str):
    return model_by_id(id)
```

**iOS (Services/ModelService.swift)** (if implemented):
```swift
func listModels() async throws -> [Model] {
    let response: ModelsResponse = try await apiClient.request(
        path: "/api/models"
    )
    return response.data
}

func getModel(id: String) async throws -> Model {
    return try await apiClient.request(
        path: "/api/models/\(id)"
    )
}
```

**Code Equivalence**: ✅ Method names match, parameters match, return types match

## Platform-Specific Additions

### Apple Intelligence Integration

The iOS app adds **on-device AI capabilities** that don't exist in the web version:

```swift
// iOS-only: Apple Intelligence
let response = try await mlxService.generate(
    prompt: userMessage,
    chatId: chatId
)
```

This is an **additive feature** that:
- Doesn't break compatibility with backend
- Falls back to cloud models when unavailable
- Provides the same user experience (streaming chat)
- Uses session management consistent with web version's approach

**Design Decision**: Platform-specific enhancements are added without modifying core equivalence.

## State Management Equivalence

### Web (Svelte Stores)
```javascript
import { writable } from 'svelte/store';

export const chats = writable([]);
export const selectedChat = writable(null);
export const isGenerating = writable(false);
```

### iOS (ObservableObject)
```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var selectedChat: Chat?
    @Published var isGenerating = false
}
```

**Code Equivalence**: ✅ Same reactive pattern, different framework

## Error Handling

### Backend Errors
```python
raise HTTPException(
    status_code=401,
    detail="Invalid credentials"
)
```

### Web Handling
```javascript
try {
    await login(email, password);
} catch (error) {
    if (error.status === 401) {
        showError("Invalid credentials");
    }
}
```

### iOS Handling
```swift
do {
    try await authService.login(email: email, password: password)
} catch let error as APIError where error.code == "401" {
    showError("Invalid credentials")
}
```

**Code Equivalence**: ✅ Same error codes, same handling pattern

## Testing Equivalence

### Backend Test
```python
def test_create_chat():
    response = client.post("/api/chats", json={
        "title": "Test Chat",
        "model_ids": ["gpt-4"]
    })
    assert response.status_code == 200
    assert response.json()["title"] == "Test Chat"
```

### iOS Test
```swift
func testCreateChat() async throws {
    let chat = try await apiClient.request(
        path: "/api/chats",
        method: "POST",
        body: CreateChatRequest(title: "Test Chat", modelIds: ["gpt-4"])
    )
    XCTAssertEqual(chat.title, "Test Chat")
}
```

**Code Equivalence**: ✅ Same test scenarios, same assertions

## Configuration Equivalence

### Web (.env)
```bash
BACKEND_URL=http://localhost:8080
DEFAULT_TEMPERATURE=0.7
DEFAULT_MAX_TOKENS=2048
ENABLE_RAG=true
```

### iOS (AppConfig.swift)
```swift
struct AppConfig {
    static let backendURL = "http://localhost:8080"
    static let defaultTemperature = 0.7
    static let defaultMaxTokens = 2048
    static let enableRAG = true
}
```

**Code Equivalence**: ✅ Same configuration values, same defaults

## Maintaining Equivalence

### When Backend Changes

1. **API Endpoint Change**:
   - Update corresponding iOS service method
   - Update path string
   - Keep method signature consistent

2. **New Field in Model**:
   - Add field to iOS struct
   - Add to CodingKeys if needed
   - Update tests

3. **New Feature**:
   - Implement corresponding service
   - Match API contract
   - Replicate business logic
   - Add UI if needed

### Code Review Checklist

When reviewing iOS code changes:
- [ ] API endpoints match backend exactly
- [ ] Request/response models match backend schemas
- [ ] Business logic matches web implementation
- [ ] Error handling is consistent
- [ ] Default values match configuration
- [ ] Tests cover same scenarios as backend

## Divergence Points (Acceptable)

### UI/UX
- **Web**: Mouse/keyboard navigation, desktop layout
- **iOS**: Touch gestures, mobile layout, native controls

**Status**: ✅ Acceptable - Platform conventions

### Storage
- **Web**: localStorage, IndexedDB
- **iOS**: Keychain, UserDefaults, Core Data

**Status**: ✅ Acceptable - Platform security requirements

### Real-time Updates
- **Web**: WebSockets, SSE
- **iOS**: URLSession streaming, WebSocket (Starscream)

**Status**: ✅ Acceptable - Platform networking APIs

### File Access
- **Web**: File input element, drag & drop
- **iOS**: Document picker, share sheet

**Status**: ✅ Acceptable - Platform file system APIs

## Benefits of Code Equivalence

### 1. Consistency
Users get the same experience across platforms:
- Same features
- Same behavior
- Same error messages
- Same data format

### 2. Maintainability
- Bug fixes in one platform suggest fixes in others
- Feature additions follow proven patterns
- Documentation applies to both platforms

### 3. Testing
- Test scenarios are shared
- Edge cases discovered on one platform apply to others
- API contract violations caught early

### 4. Collaboration
- Backend developers understand iOS code structure
- iOS developers understand backend expectations
- Easier code reviews across teams

## Future Considerations

### GraphQL Adoption
If backend moves to GraphQL:
- iOS would use Apollo or similar
- Schema would ensure type safety
- Code equivalence maintained at GraphQL level

### gRPC Adoption
If backend moves to gRPC:
- iOS would use SwiftGRPC
- Proto files shared between platforms
- Strong typing ensures equivalence

### Microservices
If backend splits into microservices:
- iOS services would map to microservices
- Each service maintains its own equivalence
- API gateway would be transparent to iOS

## Conclusion

The iOS app achieves code equivalence with the web application through:

1. **Identical API contracts** - Same endpoints, formats, errors
2. **Matching data models** - 1:1 correspondence with backend
3. **Equivalent business logic** - Same flows, same validation
4. **Consistent state management** - Same reactive patterns
5. **Platform-appropriate implementation** - Native but equivalent

This strategy ensures that the iOS app is not just a "port" but a native implementation that maintains perfect compatibility with the existing Open WebUI ecosystem while leveraging iOS-specific capabilities like Apple Intelligence.

---

**Document Version**: 1.0
**Last Updated**: 2024
**Related Documents**: 
- PROJECT_OVERVIEW.md
- APPLE_INTELLIGENCE_INTEGRATION.md
- README.md
