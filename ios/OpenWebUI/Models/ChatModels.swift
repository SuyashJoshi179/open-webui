//
//  ChatModels.swift
//  OpenWebUI
//
//  Chat-related data models
//

import Foundation

// MARK: - Chat

struct Chat: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let title: String
    let modelIds: [String]
    let createdAt: Date
    let updatedAt: Date
    let archived: Bool
    let pinned: Bool
    let tags: [String]
    let metadata: ChatMetadata?
    
    struct ChatMetadata: Codable, Equatable {
        let messageCount: Int?
        let lastMessageAt: Date?
        let systemPrompt: String?
        let temperature: Double?
        let maxTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case messageCount = "message_count"
            case lastMessageAt = "last_message_at"
            case systemPrompt = "system_prompt"
            case temperature
            case maxTokens = "max_tokens"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case modelIds = "model_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archived
        case pinned
        case tags
        case metadata
    }
}

// MARK: - Chat Session (Local state)

class ChatSession: ObservableObject, Identifiable {
    let id: String
    @Published var chat: Chat
    @Published var messages: [Message] = []
    @Published var isGenerating: Bool = false
    @Published var selectedModels: [Model] = []
    @Published var systemPrompt: String?
    @Published var temperature: Double
    @Published var maxTokens: Int
    @Published var enableRAG: Bool = false
    @Published var selectedKnowledgeBase: KnowledgeBase?
    
    init(chat: Chat) {
        self.id = chat.id
        self.chat = chat
        self.temperature = chat.metadata?.temperature ?? AppConfig.defaultTemperature
        self.maxTokens = chat.metadata?.maxTokens ?? AppConfig.defaultMaxTokens
        self.systemPrompt = chat.metadata?.systemPrompt
    }
    
    func addMessage(_ message: Message) {
        messages.append(message)
    }
    
    func updateLastMessage(content: String) {
        guard let index = messages.indices.last else { return }
        var updatedMessage = messages[index]
        updatedMessage = Message(
            id: updatedMessage.id,
            chatId: updatedMessage.chatId,
            role: updatedMessage.role,
            content: content,
            modelId: updatedMessage.modelId,
            timestamp: updatedMessage.timestamp,
            metadata: updatedMessage.metadata
        )
        messages[index] = updatedMessage
    }
}

// MARK: - Chat Request/Response

struct CreateChatRequest: Codable {
    let title: String
    let modelIds: [String]
    let systemPrompt: String?
    let metadata: Chat.ChatMetadata?
    
    enum CodingKeys: String, CodingKey {
        case title
        case modelIds = "model_ids"
        case systemPrompt = "system_prompt"
        case metadata
    }
}

struct UpdateChatRequest: Codable {
    let title: String?
    let archived: Bool?
    let pinned: Bool?
    let tags: [String]?
    let metadata: Chat.ChatMetadata?
}

struct ChatsListResponse: Codable {
    let chats: [Chat]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case chats
        case total
        case page
        case pageSize = "page_size"
    }
}

// MARK: - Message Stream Events

enum StreamEvent {
    case message(String)
    case done
    case error(Error)
    case toolCall(Tool, String)
}

// MARK: - Conversation Context

struct ConversationContext {
    let messages: [Message]
    let systemPrompt: String?
    let documents: [Document]?
    let tools: [Tool]?
    let temperature: Double
    let maxTokens: Int
    
    func toAPIMessages() -> [ChatCompletionRequest.ChatMessage] {
        var apiMessages: [ChatCompletionRequest.ChatMessage] = []
        
        // Add system prompt if present
        if let systemPrompt = systemPrompt {
            apiMessages.append(.init(role: "system", content: systemPrompt))
        }
        
        // Add conversation messages
        for message in messages {
            apiMessages.append(.init(
                role: message.role.rawValue,
                content: message.content
            ))
        }
        
        return apiMessages
    }
}

// MARK: - Chat Statistics

struct ChatStatistics: Codable {
    let totalChats: Int
    let totalMessages: Int
    let totalTokens: Int
    let favoriteModels: [String]
    
    enum CodingKeys: String, CodingKey {
        case totalChats = "total_chats"
        case totalMessages = "total_messages"
        case totalTokens = "total_tokens"
        case favoriteModels = "favorite_models"
    }
}
