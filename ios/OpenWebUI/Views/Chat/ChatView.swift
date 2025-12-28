//
//  ChatView.swift
//  OpenWebUI
//
//  Main chat interface
//

import SwiftUI
import MarkdownUI

struct ChatView: View {
    let chat: Chat
    
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    init(chat: Chat) {
        self.chat = chat
        self._viewModel = StateObject(wrappedValue: ChatViewModel(chat: chat))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isGenerating {
                            TypingIndicatorView()
                        }
                        
                        // Performance insights
                        if let ttft = viewModel.ttft, let tps = viewModel.tokensPerSecond {
                            PerformanceInsightsView(ttft: ttft, tokensPerSecond: tps)
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input bar
            inputBar
        }
        .navigationTitle(chat.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {}) {
                        Label("Model Settings", systemImage: "cpu")
                    }
                    Button(action: {}) {
                        Label("Enable RAG", systemImage: "doc.text")
                    }
                    Button(action: {}) {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadMessages()
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(20)
                .focused($isInputFocused)
                .lineLimit(1...5)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.isEmpty ? .gray : .blue)
            }
            .disabled(messageText.isEmpty || viewModel.isGenerating)
        }
        .padding()
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    // Render markdown for assistant messages
                    Markdown(message.content)
                        .markdownTextStyle {
                            FontSize(15)
                            ForegroundColor(.primary)
                        }
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            configuration.label
                                .padding()
                                .markdownTextStyle {
                                    FontFamilyVariant(.monospaced)
                                    FontSize(.em(0.85))
                                }
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .markdownMargin(top: .zero, bottom: .em(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                } else {
                    // Plain text for user messages
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

struct PerformanceInsightsView: View {
    let ttft: TimeInterval
    let tokensPerSecond: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 16) {
                // TTFT
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text("TTFT: \(String(format: "%.2f", ttft))s")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                
                // Tokens per second
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption)
                    Text("\(String(format: "%.1f", tokensPerSecond)) tokens/s")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TypingIndicatorView: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animationAmount)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationAmount
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            animationAmount = -5
        }
    }
}

// MARK: - View Model

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var ttft: TimeInterval? // Time To First Token
    @Published var tokensPerSecond: Double? // Tokens per second
    
    private let chat: Chat
    private let chatStorage = ChatStorage.shared
    private var firstTokenTime: Date?
    private var generationStartTime: Date?
    private var tokenCount: Int = 0
    
    init(chat: Chat) {
        self.chat = chat
    }
    
    func loadMessages() async {
        // Load messages from local storage
        if let storedChat = chatStorage.chats.first(where: { $0.id == chat.id }) {
            // Messages are now part of Chat, but let's keep them separate in the view
            // For now, just load the welcome message if it's the welcome chat
            if chat.id == "welcome" {
                messages = [
                    Message(
                        id: "welcome-1",
                        chatId: chat.id,
                        role: .assistant,
                        content: "👋 Welcome to Open WebUI for iOS!\n\nThis app uses Apple Intelligence to provide on-device AI assistance. Your conversations stay completely private on your iPhone.\n\nType a message below to start chatting!",
                        timestamp: Date()
                    )
                ]
            }
        }
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = Message(
            id: UUID().uuidString,
            chatId: chat.id,
            role: .user,
            content: content,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        isGenerating = true
        errorMessage = nil
        
        do {
            // Check if Apple Intelligence is available
            if #available(iOS 26.0, *) {
                let mlxService = MLXService.shared
                if !mlxService.isModelAvailable {
                    await mlxService.checkAvailability()
                }
                
                if mlxService.isModelAvailable {
                // Use Apple Intelligence (on-device)
                var assistantContent = ""
                
                // Reset performance metrics
                ttft = nil
                tokensPerSecond = nil
                firstTokenTime = nil
                tokenCount = 0
                generationStartTime = Date()
                
                // Create assistant message placeholder
                let assistantMessage = Message(
                    id: UUID().uuidString,
                    chatId: chat.id,
                    role: .assistant,
                    content: "",
                    timestamp: Date()
                )
                messages.append(assistantMessage)
                
                // Stream response from Apple Intelligence
                for try await chunk in mlxService.streamGenerate(
                    modelName: "apple-intelligence",
                    prompt: content,
                    chatId: chat.id
                ) {
                    // Track first token time
                    if firstTokenTime == nil, let startTime = generationStartTime {
                        firstTokenTime = Date()
                        ttft = firstTokenTime!.timeIntervalSince(startTime)
                    }
                    
                    assistantContent += chunk
                    tokenCount += chunk.split(separator: " ").count // Rough token estimate
                    
                    // Calculate tokens per second
                    if let startTime = generationStartTime {
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed > 0 {
                            tokensPerSecond = Double(tokenCount) / elapsed
                        }
                    }
                    
                    // Update the last message
                    if let lastIndex = messages.indices.last {
                        messages[lastIndex] = Message(
                            id: messages[lastIndex].id,
                            chatId: chat.id,
                            role: .assistant,
                            content: assistantContent,
                            timestamp: messages[lastIndex].timestamp
                        )
                    }
                }
                }
            } else {
                // Apple Intelligence not available - iOS version or device issue
                let errorMsg = Message(
                    id: UUID().uuidString,
                    chatId: chat.id,
                    role: .assistant,
                    content: "⚠️ Apple Intelligence requires iOS 26 or later.\n\nYour device: iOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
                    timestamp: Date()
                )
                messages.append(errorMsg)
            }
        } catch {
            errorMessage = error.localizedDescription
            
            let errorMsg = Message(
                id: UUID().uuidString,
                chatId: chat.id,
                role: .assistant,
                content: "❌ Error: \(error.localizedDescription)",
                timestamp: Date()
            )
            messages.append(errorMsg)
        }
        
        isGenerating = false
        
        // Save chat with updated messages
        saveChatState()
    }
    
    private func saveChatState() {
        // Update chat in storage with latest messages
        // Note: This is a simplified version. In production, you'd want to
        // properly update the Chat model with message references
    }
}

#Preview {
    NavigationStack {
        ChatView(chat: Chat(
            id: "1",
            title: "Test Chat",
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
