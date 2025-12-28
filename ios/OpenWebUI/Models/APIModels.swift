//
//  APIModels.swift
//  OpenWebUI
//
//  Data models matching backend API schemas
//

import Foundation

// MARK: - API Response Wrapper

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
}

// MARK: - User Models

public struct User: Codable, Identifiable {
    public let id: String
    public let email: String
    public let name: String
    public let role: UserRole
    public let profileImageUrl: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    public enum UserRole: String, Codable {
        case admin
        case user
        case pending
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case role
        case profileImageUrl = "profile_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Authentication Models

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct SignupRequest: Codable {
    let email: String
    let password: String
    let name: String
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Model Models

struct Model: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let provider: ModelProvider
    let owned_by: String?
    let capabilities: ModelCapabilities?
    let info: ModelInfo?
    
    enum ModelProvider: String, Codable {
        case openai
        case ollama
        case local
        case custom
    }
    
    struct ModelCapabilities: Codable, Hashable {
        let chat: Bool?
        let completion: Bool?
        let embedding: Bool?
        let vision: Bool?
        let functionCalling: Bool?
        
        enum CodingKeys: String, CodingKey {
            case chat
            case completion
            case embedding
            case vision
            case functionCalling = "function_calling"
        }
    }
    
    struct ModelInfo: Codable, Hashable {
        let contextLength: Int?
        let parameters: String?
        let quantization: String?
        
        enum CodingKeys: String, CodingKey {
            case contextLength = "context_length"
            case parameters
            case quantization
        }
    }
}

struct ModelsResponse: Codable {
    let data: [Model]
}

// MARK: - Chat Models (defined in separate file)
// See ChatModels.swift

// MARK: - Message Models

public struct Message: Codable, Identifiable, Equatable {
    public let id: String
    public let chatId: String
    public let role: MessageRole
    public let content: String
    public let modelId: String?
    public let timestamp: Date
    public let metadata: MessageMetadata?
    
    public init(id: String, chatId: String = "", role: MessageRole, content: String, modelId: String? = nil, timestamp: Date, metadata: MessageMetadata? = nil) {
        self.id = id
        self.chatId = chatId
        self.role = role
        self.content = content
        self.modelId = modelId
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    public enum MessageRole: String, Codable {
        case system
        case user
        case assistant
        case function
    }
    
    public struct MessageMetadata: Codable, Equatable {
        public let tokens: Int?
        public let finishReason: String?
        public let functionCall: FunctionCall?
        
        enum CodingKeys: String, CodingKey {
            case tokens
            case finishReason = "finish_reason"
            case functionCall = "function_call"
        }
    }
    
    public struct FunctionCall: Codable, Equatable {
        public let name: String
        public let arguments: String
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case role
        case content
        case modelId = "model_id"
        case timestamp
        case metadata
    }
}

// MARK: - Chat Completion Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool?
    let tools: [Tool]?
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
        case tools
    }
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        struct ChatMessage: Codable {
            let role: String
            let content: String?
            let functionCall: FunctionCall?
            
            struct FunctionCall: Codable {
                let name: String
                let arguments: String
            }
            
            enum CodingKeys: String, CodingKey {
                case role
                case content
                case functionCall = "function_call"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Tool Models

struct Tool: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let parameters: ToolParameters
    let enabled: Bool
    
    struct ToolParameters: Codable, Hashable {
        let type: String
        let properties: [String: ParameterProperty]
        let required: [String]?
        
        struct ParameterProperty: Codable, Hashable {
            let type: String
            let description: String?
            let `enum`: [String]?
        }
    }
}

// MARK: - Document Models (RAG)

struct Document: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let size: Int64
    let uploadedAt: Date
    let metadata: DocumentMetadata?
    
    struct DocumentMetadata: Codable {
        let pages: Int?
        let chunks: Int?
        let indexed: Bool
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case size
        case uploadedAt = "uploaded_at"
        case metadata
    }
}

// MARK: - Knowledge Base Models

struct KnowledgeBase: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let documentIds: [String]
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case documentIds = "document_ids"
        case createdAt = "created_at"
    }
}

// MARK: - Error Models

struct APIError: Codable, LocalizedError {
    let code: String
    let message: String
    let details: [String: String]?
    
    var errorDescription: String? {
        return message
    }
}
