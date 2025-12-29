//
//  ConfiguredAIModel.swift
//  OpenWebUI
//
//  Represents a configured model instance that users can select and use.
//  Each model belongs to a backend and has its own configuration.
//

import Foundation

/// A configured AI model instance
struct ConfiguredAIModel: Identifiable, Codable, Hashable {
    /// Unique identifier for this model instance
    let id: UUID
    
    /// ID of the backend that provides this model
    let backendId: String
    
    /// User-facing display name (e.g., "GPT-4 Turbo", "My Claude Model")
    var displayName: String
    
    /// Backend-specific model identifier (e.g., "gpt-4-turbo", "claude-3-sonnet")
    let modelIdentifier: String
    
    /// Model-specific configuration
    var configuration: ModelConfiguration
    
    /// Model capabilities
    let capabilities: ModelCapabilities
    
    /// Get reference to parent backend (computed at runtime, main actor isolated)
    @MainActor
    var backend: AIBackend? {
        BackendManager.shared.getBackend(id: backendId)
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, backendId, displayName, modelIdentifier, configuration, capabilities
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ConfiguredAIModel, rhs: ConfiguredAIModel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Model-specific configuration settings
struct ModelConfiguration: Codable, Hashable {
    // MARK: - Model Identity
    
    /// Display name for the model
    var displayName: String?
    
    /// Backend-specific model identifier (e.g., "gpt-4", "claude-3-sonnet")
    var modelIdentifier: String?
    
    // MARK: - Connection Settings (for API-based models)
    
    /// API endpoint URL
    var apiURL: String?
    
    /// API authentication key
    var apiKey: String?
    
    /// Organization ID (for OpenAI)
    var organizationId: String?
    
    // MARK: - Generation Parameters
    
    /// Maximum tokens to generate
    var maxTokens: Int = 2048
    
    /// Sampling temperature (0.0 - 2.0)
    var temperature: Double = 0.7
    
    /// Nucleus sampling threshold (0.0 - 1.0)
    var topP: Double = 0.9
    
    /// Top-K sampling parameter
    var topK: Int = 50
    
    /// Frequency penalty (-2.0 - 2.0)
    var frequencyPenalty: Double = 0.0
    
    /// Presence penalty (-2.0 - 2.0)
    var presencePenalty: Double = 0.0
    
    // MARK: - Local Model Settings (for Llama.cpp, LiteRT)
    
    /// Path to local model file
    var modelPath: String?
    
    /// Context window size
    var contextSize: Int?
    
    /// Number of layers to offload to GPU
    var gpuLayers: Int?
    
    /// Number of CPU threads to use
    var threads: Int?
    
    /// Use GPU acceleration (for LiteRT)
    var useGPU: Bool = true
    
    // MARK: - Initialization
    
    init(
        apiURL: String? = nil,
        apiKey: String? = nil,
        organizationId: String? = nil,
        maxTokens: Int = 2048,
        temperature: Double = 0.7,
        topP: Double = 0.9,
        topK: Int = 50,
        frequencyPenalty: Double = 0.0,
        presencePenalty: Double = 0.0,
        modelPath: String? = nil,
        contextSize: Int? = nil,
        gpuLayers: Int? = nil,
        threads: Int? = nil,
        useGPU: Bool = true
    ) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.organizationId = organizationId
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.modelPath = modelPath
        self.contextSize = contextSize
        self.gpuLayers = gpuLayers
        self.threads = threads
        self.useGPU = useGPU
    }
}

/// Model capabilities - what the model can do
struct ModelCapabilities: Codable, Hashable {
    /// Supports streaming responses
    let supportsStreaming: Bool
    
    /// Supports vision/image inputs
    let supportsVision: Bool
    
    /// Supports function/tool calling
    let supportsFunctionCalling: Bool
    
    /// Maximum context length in tokens
    let maxContextLength: Int
    
    /// Maximum output tokens per response
    let maxOutputTokens: Int
    
    /// Supports embeddings generation
    let supportsEmbeddings: Bool
    
    init(
        supportsStreaming: Bool = true,
        supportsVision: Bool = false,
        supportsFunctionCalling: Bool = false,
        maxContextLength: Int = 4096,
        maxOutputTokens: Int = 2048,
        supportsEmbeddings: Bool = false
    ) {
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
        self.supportsFunctionCalling = supportsFunctionCalling
        self.maxContextLength = maxContextLength
        self.maxOutputTokens = maxOutputTokens
        self.supportsEmbeddings = supportsEmbeddings
    }
}
