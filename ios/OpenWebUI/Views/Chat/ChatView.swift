//
//  ChatView.swift
//  OpenWebUI
//
//  Main chat interface
//

import SwiftUI

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
        .navigationBarTitleDisplayMode(.inline)
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
                .background(Color(.systemGray6))
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
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
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
        .background(Color(.systemGray5))
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
    
    private let chat: Chat
    private let apiClient = APIClient.shared
    private let openAIService = OpenAIService.shared
    private let ollamaService = OllamaService.shared
    private let mlxService = MLXService.shared
    
    init(chat: Chat) {
        self.chat = chat
    }
    
    func loadMessages() async {
        do {
            let response: [Message] = try await apiClient.request(
                path: "/api/chats/\(chat.id)/messages"
            )
            messages = response
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = Message(
            id: UUID().uuidString,
            chatId: chat.id,
            role: .user,
            content: content,
            modelId: nil,
            timestamp: Date(),
            metadata: nil
        )
        messages.append(userMessage)
        
        isGenerating = true
        
        do {
            // Prepare chat messages
            let chatMessages = messages.map { message in
                ChatCompletionRequest.ChatMessage(
                    role: message.role.rawValue,
                    content: message.content
                )
            }
            
            // Use the first model from chat configuration
            let modelId = chat.modelIds.first ?? "gpt-3.5-turbo"
            
            // Stream the response
            var assistantContent = ""
            
            // Create assistant message placeholder
            let assistantMessage = Message(
                id: UUID().uuidString,
                chatId: chat.id,
                role: .assistant,
                content: "",
                modelId: modelId,
                timestamp: Date(),
                metadata: nil
            )
            messages.append(assistantMessage)
            
            for try await chunk in openAIService.streamChatCompletion(
                model: modelId,
                messages: chatMessages
            ) {
                if let data = chunk.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    assistantContent += content
                    
                    // Update the last message
                    if let index = messages.indices.last {
                        var updatedMessage = messages[index]
                        updatedMessage = Message(
                            id: updatedMessage.id,
                            chatId: updatedMessage.chatId,
                            role: updatedMessage.role,
                            content: assistantContent,
                            modelId: updatedMessage.modelId,
                            timestamp: updatedMessage.timestamp,
                            metadata: updatedMessage.metadata
                        )
                        messages[index] = updatedMessage
                    }
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isGenerating = false
    }
}

#Preview {
    NavigationStack {
        ChatView(chat: Chat(
            id: "1",
            userId: "user1",
            title: "Test Chat",
            modelIds: ["gpt-3.5-turbo"],
            createdAt: Date(),
            updatedAt: Date(),
            archived: false,
            pinned: false,
            tags: [],
            metadata: nil
        ))
    }
}
