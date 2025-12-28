# Streaming and Context Fixes for Apple Intelligence

## Problem
The streaming feature in the iOS app had two critical issues:
1. **Output was repeating** - Sections of responses would appear multiple times
2. **Model had no context** - The AI didn't remember previous messages in the conversation

## Root Causes

### Issue 1: Repeating Output
The streaming API was yielding `part.content` which contains the **full cumulative text** at each step, not just new deltas. This caused the same text to appear multiple times as we appended each chunk.

### Issue 2: No Context
For each message, we were creating a **temporary session** with `UUID().uuidString`, then immediately clearing it after the response. This meant:
- Each request started fresh with no memory
- Previous conversation history was lost
- The AI couldn't maintain context across messages

## Solutions Implemented

### Fix 1: Delta-Only Streaming
Modified `MLXService.streamGenerate()` to track previously yielded content and only emit new deltas:

```swift
var previousContent = ""
for try await part in stream {
    let currentContent = part.content
    if currentContent.hasPrefix(previousContent) {
        let delta = String(currentContent.dropFirst(previousContent.count))
        if !delta.isEmpty {
            continuation.yield(delta)
        }
    } else {
        continuation.yield(currentContent)
    }
    previousContent = currentContent
}
```

### Fix 2: Persistent Chat Sessions
1. **Added chatId parameter** to `streamGenerate()`:
```swift
func streamGenerate(
    modelName: String,
    prompt: String,
    chatId: String,  // NEW: Use chat-specific session
    maxTokens: Int = 2048,
    temperature: Double = 0.7,
    topP: Double = 0.9
)
```

2. **Reuse sessions per chat** instead of creating temporary ones:
```swift
// Before: Created temp session (no context)
let tempSessionId = UUID().uuidString
guard let session = getSession(for: tempSessionId) else { ... }
...
clearSession(for: tempSessionId)  // Destroyed session!

// After: Use persistent chat session (maintains context)
guard let session = getSession(for: chatId) else { ... }
// Session persists for the entire chat lifetime
```

3. **Updated ChatViewModel** to pass the chatId:
```swift
for try await chunk in mlxService.streamGenerate(
    modelName: "apple-intelligence",
    prompt: content,
    chatId: chat.id  // NEW: Pass chat ID
) {
    assistantContent += chunk
    // ...
}
```

## Files Modified

1. **[ios/OpenWebUI/Services/MLXService.swift](ios/OpenWebUI/Services/MLXService.swift#L150-L180)**
   - Added `chatId` parameter to `streamGenerate()`
   - Implemented delta-only streaming logic
   - Removed session cleanup to preserve context

2. **[ios/OpenWebUI/Views/Chat/ChatView.swift](ios/OpenWebUI/Views/Chat/ChatView.swift#L235-L240)**
   - Updated `streamGenerate()` call to pass `chat.id`

## How It Works Now

1. **First message in a chat**:
   - `MLXService` creates a new `LanguageModelSession` for this chatId
   - Session is stored in the `sessions` dictionary
   - Model receives the prompt and generates a response
   - Only new text deltas are yielded to the UI

2. **Subsequent messages**:
   - Same session is retrieved from the dictionary using chatId
   - Model has full conversation history (maintained by LanguageModelSession)
   - Responses consider previous context
   - Only new deltas are streamed

3. **Different chats**:
   - Each chat has its own session ID (the chat's UUID)
   - Sessions remain independent
   - Switching between chats maintains separate contexts

## Testing

To verify the fixes work:

1. **Test streaming without repetition**:
   - Send a message asking for a long response (e.g., "Write a story about a robot")
   - Verify text appears once without duplicates

2. **Test conversation context**:
   - Send: "My favorite color is blue"
   - Then: "What's my favorite color?"
   - AI should remember and respond correctly

3. **Test multiple chats**:
   - Create Chat A, discuss topic X
   - Create Chat B, discuss topic Y
   - Switch back to Chat A - should remember topic X
   - Switch to Chat B - should remember topic Y

## Technical Details

### LanguageModelSession Behavior
The FoundationModels framework's `LanguageModelSession` automatically maintains conversation history. Each call to `streamResponse(to: prompt)` appends to the internal conversation state.

### Delta Calculation
The streaming API provides cumulative content, so we calculate deltas by:
1. Store `previousContent` from the last iteration
2. Check if new `currentContent` starts with `previousContent`
3. Extract the delta: `currentContent.dropFirst(previousContent.count)`
4. Only yield non-empty deltas

This ensures smooth, non-repetitive streaming display.

## Deployment

App successfully built and deployed to iPhone 17 (00008150-001664343C78401C) with these fixes.

## Date
December 27, 2025
