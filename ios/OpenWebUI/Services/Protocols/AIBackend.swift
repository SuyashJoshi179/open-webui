//
//  AIBackend.swift
//  OpenWebUI
//
//  Core protocol for AI backends in the model-centric architecture.
//  Backends are model providers that manage collections of configured models.
//

import Foundation
import SwiftUI

/// Core protocol that all AI backends must implement
/// Backends serve as model providers in the new architecture
@MainActor
protocol AIBackend: AnyObject, Identifiable {
    /// Unique identifier for the backend
    var id: String { get }
    
    /// Human-readable name of the backend
    var name: String { get }
    
    /// Description of the backend and its capabilities
    var description: String { get }
    
    /// Icon name for the backend (SF Symbol)
    var iconName: String { get }
    
    /// Backend-level settings that apply to all models
    var backendSettings: AIBackendSettings { get set }
    
    // MARK: - Model Management
    
    /// Get all configured models for this backend
    /// - Returns: Array of configured model instances
    func getConfiguredModels() -> [ConfiguredAIModel]
    
    /// Add a new model to this backend
    /// - Parameter config: Configuration for the new model
    /// - Returns: The newly created configured model
    /// - Throws: BackendError if the model cannot be added
    func addModel(_ config: ModelConfiguration) throws -> ConfiguredAIModel
    
    /// Remove a model from this backend
    /// - Parameter modelId: ID of the model to remove
    /// - Throws: BackendError if the model cannot be removed
    func removeModel(_ modelId: UUID) throws
    
    /// Update an existing model's configuration
    /// - Parameters:
    ///   - modelId: ID of the model to update
    ///   - config: New configuration
    /// - Throws: BackendError if the model cannot be updated
    func updateModel(_ modelId: UUID, config: ModelConfiguration) throws
    
    // MARK: - Capabilities
    
    /// Whether this backend supports adding new models
    func supportsModelAddition() -> Bool
    
    /// Whether this backend supports removing models
    func supportsModelRemoval() -> Bool
    
    // MARK: - Operations
    
    /// Initialize the backend and prepare it for use
    /// - Throws: BackendError if initialization fails
    func initialize() async throws
    
    /// Stream text generation from a specific model
    /// - Parameters:
    ///   - modelId: ID of the configured model to use
    ///   - prompt: Input prompt
    ///   - context: Additional context (chat history, system prompt, etc.)
    /// - Returns: Async stream of text chunks
    func streamGenerate(
        modelId: UUID,
        prompt: String,
        context: AIContext
    ) -> AsyncThrowingStream<String, Error>
    
    /// Cleanup resources when backend is no longer needed
    func cleanup() async
}

// MARK: - Supporting Types

/// Message representation for conversation history
struct AIMessage: Codable, Hashable {
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

/// Additional model metadata
struct ModelMetadata: Codable, Hashable {
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
    case modelNotFound
    case backendNotFound
    case noActiveModel
    case generationFailed(String)
    case invalidConfiguration(String)
    case networkError(String)
    case authenticationFailed
    case quotaExceeded
    case operationNotSupported
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Backend is not available on this device"
        case .notInitialized:
            return "Backend has not been initialized"
        case .initializationFailed(let message):
            return "Failed to initialize backend: \(message)"
        case .modelNotFound:
            return "Model not found"
        case .backendNotFound:
            return "Backend not found"
        case .noActiveModel:
            return "No model is currently selected"
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
        case .operationNotSupported:
            return "This operation is not supported by this backend"
        }
    }
}
