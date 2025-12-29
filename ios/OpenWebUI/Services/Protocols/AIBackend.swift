//
//  AIBackend.swift
//  OpenWebUI
//
//  Core protocol that all AI backends must implement
//

import Foundation
import SwiftUI

/// Core protocol that defines the interface for all AI backends
@MainActor
protocol AIBackend: AnyObject, Identifiable {
    /// Unique identifier for the backend
    var id: String { get }
    
    /// Human-readable name of the backend
    var name: String { get }
    
    /// Description of the backend and its capabilities
    var description: String { get }
    
    /// Whether the backend is currently available and ready to use
    var isAvailable: Bool { get }
    
    /// Icon name for the backend (SF Symbol)
    var iconName: String { get }
    
    /// Backend-specific settings
    var settings: AIBackendSettings { get }
    
    /// Initialize the backend and prepare it for use
    /// - Throws: BackendError if initialization fails
    func initialize() async throws
    
    /// Check if the backend is available on this device
    /// - Returns: true if the backend can be used
    func checkAvailability() async -> Bool
    
    /// List all models available for this backend
    /// - Returns: Array of available models
    func listModels() async throws -> [AIModel]
    
    /// Stream text generation from the model
    /// - Parameters:
    ///   - model: Model identifier to use
    ///   - prompt: Input prompt
    ///   - context: Additional context (chat history, system prompt, etc.)
    ///   - parameters: Generation parameters (temperature, top_p, etc.)
    /// - Returns: Async stream of text chunks
    func streamGenerate(
        model: String,
        prompt: String,
        context: AIContext,
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<String, Error>
    
    /// Cleanup resources when backend is no longer needed
    func cleanup() async
}

/// Additional capabilities that backends may support
protocol AIBackendCapabilities {
    /// Whether the backend supports embeddings
    var supportsEmbeddings: Bool { get }
    
    /// Whether the backend supports vision/image understanding
    var supportsVision: Bool { get }
    
    /// Whether the backend supports function calling
    var supportsFunctionCalling: Bool { get }
    
    /// Maximum context length supported
    var maxContextLength: Int { get }
}

/// Message representation for conversation history in AI backends
struct AIMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date?
    
    init(role: String, content: String, timestamp: Date? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// Context information for AI generation
struct AIContext {
    let chatId: String
    let systemPrompt: String?
    let conversationHistory: [AIMessage]
    let metadata: [String: Any]?
    
    init(
        chatId: String,
        systemPrompt: String? = nil,
        conversationHistory: [AIMessage] = [],
        metadata: [String: Any]? = nil
    ) {
        self.chatId = chatId
        self.systemPrompt = systemPrompt
        self.conversationHistory = conversationHistory
        self.metadata = metadata
    }
}

/// Parameters for text generation
struct GenerationParameters {
    var temperature: Double
    var topP: Double
    var topK: Int?
    var maxTokens: Int
    var stopSequences: [String]
    var frequencyPenalty: Double?
    var presencePenalty: Double?
    
    static let `default` = GenerationParameters(
        temperature: 0.7,
        topP: 0.9,
        topK: nil,
        maxTokens: 2048,
        stopSequences: [],
        frequencyPenalty: nil,
        presencePenalty: nil
    )
}

/// Common model representation across all backends
struct AIModel: Identifiable, Codable {
    let id: String
    let name: String
    let backendId: String
    let description: String?
    let capabilities: ModelCapabilities
    let metadata: ModelMetadata?
    
    init(
        id: String,
        name: String,
        backendId: String,
        description: String? = nil,
        capabilities: ModelCapabilities = .default,
        metadata: ModelMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.backendId = backendId
        self.description = description
        self.capabilities = capabilities
        self.metadata = metadata
    }
}

/// Model capabilities
struct ModelCapabilities: Codable {
    let supportsStreaming: Bool
    let supportsVision: Bool
    let supportsFunctionCalling: Bool
    let maxContextLength: Int
    let maxOutputTokens: Int
    
    static let `default` = ModelCapabilities(
        supportsStreaming: true,
        supportsVision: false,
        supportsFunctionCalling: false,
        maxContextLength: 4096,
        maxOutputTokens: 2048
    )
}

/// Additional model metadata
struct ModelMetadata: Codable {
    let size: Int64?
    let family: String?
    let version: String?
    let parameters: String?
    let quantization: String?
    let createdAt: Date?
    
    init(
        size: Int64? = nil,
        family: String? = nil,
        version: String? = nil,
        parameters: String? = nil,
        quantization: String? = nil,
        createdAt: Date? = nil
    ) {
        self.size = size
        self.family = family
        self.version = version
        self.parameters = parameters
        self.quantization = quantization
        self.createdAt = createdAt
    }
}

/// Errors that backends can throw
enum BackendError: LocalizedError {
    case notAvailable
    case notInitialized
    case initializationFailed(String)
    case modelNotFound(String)
    case generationFailed(String)
    case invalidConfiguration(String)
    case networkError(String)
    case authenticationFailed
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Backend is not available on this device"
        case .notInitialized:
            return "Backend has not been initialized"
        case .initializationFailed(let message):
            return "Failed to initialize backend: \(message)"
        case .modelNotFound(let modelId):
            return "Model not found: \(modelId)"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .quotaExceeded:
            return "API quota exceeded. Please try again later."
        }
    }
}
