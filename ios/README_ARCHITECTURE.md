# Multi-Backend Architecture - Quick Reference

## 📁 Files Created

### Core Architecture
1. **AIBackend.swift** - Core protocol defining backend interface
2. **AIBackendSettings.swift** - Settings protocol and UI components
3. **BackendManager.swift** - Central coordinator for all backends

### Backend Implementations
4. **LlamaCppBackend.swift** - Local inference with GGUF models
5. **LiteRTBackend.swift** - TensorFlow Lite on-device inference

### UI Components
6. **BackendSelectionView.swift** - UI for selecting and managing backends

### Documentation
7. **ARCHITECTURE.md** - Complete architecture documentation
8. **MIGRATION.md** - Step-by-step migration guide
9. **IMPLEMENTATION_CHECKLIST.md** - Detailed task checklist
10. **DESIGN.md** - Visual design and SOLID principles
11. **README.md** - This file

---

## 🚀 Quick Start

### 1. Understanding the Architecture

Read in this order:
1. **DESIGN.md** - Overview and visual diagrams
2. **ARCHITECTURE.md** - Detailed technical specs
3. **MIGRATION.md** - Implementation steps

### 2. Key Concepts

**AIBackend Protocol** - All backends implement this:
```swift
protocol AIBackend {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get }
    func streamGenerate(...) -> AsyncThrowingStream<String, Error>
}
```

**BackendManager** - Single source of truth:
```swift
let backend = BackendManager.shared.activeBackend
let stream = backend.streamGenerate(...)
```

**Settings** - Each backend defines its own:
```swift
struct MyBackendSettings: AIBackendSettings {
    var backendId = "my-backend"
    // Backend-specific settings
}
```

### 3. Adding a New Backend

```swift
// 1. Create backend class
class MyBackend: AIBackend {
    let id = "my-backend"
    let name = "My Backend"
    // ... implement protocol
}

// 2. Create settings
struct MyBackendSettings: AIBackendSettings {
    // ... settings
}

// 3. Register in app
BackendManager.shared.registerBackend(MyBackend())
```

---

## 🎯 SOLID Principles Summary

| Principle | Implementation |
|-----------|----------------|
| **Single Responsibility** | Each backend handles only its AI provider |
| **Open/Closed** | Add new backends without modifying existing code |
| **Liskov Substitution** | All backends are interchangeable |
| **Interface Segregation** | Focused protocols, no bloat |
| **Dependency Inversion** | Depend on protocols, not implementations |

---

## 📋 Implementation Checklist (High Level)

- [ ] **Phase 1:** Protocol layer ✅ (DONE)
- [ ] **Phase 2:** Refactor existing backends
  - [ ] AppleFoundationBackend (from MLXService)
  - [ ] OpenAICompatibleBackend (from OpenAIService)
- [ ] **Phase 3:** Update ViewModels
  - [ ] ChatViewModel
  - [ ] ModelsViewModel
- [ ] **Phase 4:** Update UI
  - [ ] Settings integration
  - [ ] Backend selection
- [ ] **Phase 5:** Add new backends
  - [ ] Llama.cpp (scaffolded ✅)
  - [ ] LiteRT (scaffolded ✅)
- [ ] **Phase 6:** Testing & Documentation

See [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md) for detailed tasks.

---

## 🔧 Current State vs Target State

### Current State (Before Migration)
```
ChatViewModel
    ├─ MLXService.shared
    └─ OpenAIService.shared
```

### Target State (After Migration)
```
ChatViewModel
    └─ BackendManager.shared
        ├─ AppleFoundationBackend
        ├─ OpenAICompatibleBackend
        ├─ LlamaCppBackend
        └─ LiteRTBackend
```

---

## 🎨 Architecture Diagram (Simplified)

```
┌──────────────────────────────────────┐
│          UI Layer (SwiftUI)          │
└────────────────┬─────────────────────┘
                 │
┌────────────────┴─────────────────────┐
│       ViewModels (ObservableObject)  │
└────────────────┬─────────────────────┘
                 │
┌────────────────┴─────────────────────┐
│      BackendManager (Singleton)      │
└────────────────┬─────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────┴────────┐ ┌─────┴──────────┐
│  AIBackend     │ │ AIBackend      │
│  (Protocol)    │ │ (Protocol)     │
│                │ │                │
│ ┌────────────┐ │ │ ┌────────────┐ │
│ │  Apple     │ │ │ │  OpenAI    │ │
│ │Foundation  │ │ │ │ Compatible │ │
│ └────────────┘ │ │ └────────────┘ │
└────────────────┘ └────────────────┘
```

---

## 📖 Code Examples

### Before (Old Way)
```swift
class ChatViewModel {
    func sendMessage() async {
        let mlx = MLXService.shared
        for try await chunk in mlx.streamGenerate(...) {
            // Handle chunk
        }
    }
}
```

### After (New Way)
```swift
class ChatViewModel {
    @ObservedObject var backendManager = BackendManager.shared
    
    func sendMessage() async {
        guard let backend = backendManager.activeBackend else { return }
        
        let stream = backend.streamGenerate(
            model: selectedModel,
            prompt: text,
            context: AIContext(chatId: chat.id),
            parameters: .default
        )
        
        for try await chunk in stream {
            // Handle chunk - works with ANY backend
        }
    }
}
```

---

## 🔍 Finding Things

| What You Need | Where to Look |
|---------------|---------------|
| Overall design | DESIGN.md |
| Technical details | ARCHITECTURE.md |
| How to migrate | MIGRATION.md |
| Task list | IMPLEMENTATION_CHECKLIST.md |
| Core protocols | Services/Protocols/ |
| Backend implementations | Services/Backends/ |
| UI components | Views/Settings/ |

---

## ⚡ Quick Commands

```bash
# Create folder structure
mkdir -p OpenWebUI/Services/Backends
mkdir -p OpenWebUI/Services/Settings
mkdir -p OpenWebUI/Services/Protocols

# Find TODOs in code
grep -r "TODO" OpenWebUI/

# Count lines of code
find OpenWebUI/Services -name "*.swift" | xargs wc -l
```

---

## 🎓 Learning Path

For developers new to this architecture:

1. **Day 1:** Read DESIGN.md, understand SOLID principles
2. **Day 2:** Study AIBackend protocol and one implementation
3. **Day 3:** Understand BackendManager and how registration works
4. **Day 4:** Look at settings architecture
5. **Day 5:** Start contributing - pick a task from checklist!

---

## 🤝 Contributing

When adding a new backend:

1. Create class implementing `AIBackend`
2. Create settings struct implementing `AIBackendSettings`
3. Create settings view (SwiftUI)
4. Register in app initialization
5. Write tests
6. Update documentation

---

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Backend not showing | Did you register it? |
| Settings not saving | Check `BackendSettingsManager.saveSettings()` |
| Model not available | Check backend.isAvailable |
| Generation fails | Check backend initialization |
| UI not updating | Make sure backend manager is ObservableObject |

---

## 📞 Getting Help

1. Check existing documentation files
2. Look at example implementations (Llama.cpp, LiteRT)
3. Review tests (once created)
4. Ask team members

---

## ✅ Definition of Done

A backend is considered complete when:

- [ ] Implements all AIBackend protocol methods
- [ ] Has working settings struct and view
- [ ] Can list models
- [ ] Can generate text (streaming)
- [ ] Has unit tests (>80% coverage)
- [ ] Has integration tests
- [ ] Documentation is updated
- [ ] Code review approved

---

**Next Steps:**
1. Read [DESIGN.md](DESIGN.md) for visual overview
2. Follow [MIGRATION.md](MIGRATION.md) to start implementation
3. Track progress in [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md)

*Happy Coding! 🚀*
