//
//  MLXService.swift
//  OpenWebUI
//
//  Local inference using Apple's FoundationModels framework
//  This provides on-device Apple Intelligence LLM capabilities
//

import Foundation
import FoundationModels // iOS 18+ framework for on-device LLM

@MainActor
class MLXService: ObservableObject {
    static let shared = MLXService()
    
    // Session management - holds conversation context
    private var sessions: [String: LanguageModelSession] = [:]
    
    @Published var isModelAvailable: Bool = false
    @Published var modelStatus: ModelAvailabilityStatus = .checking
    
    private let modelsDirectory = AppConfig.modelsDirectory
    
    enum ModelAvailabilityStatus {
        case checking
        case available
        case unavailable(String)
        case downloading
        case disabled
    }
    
    private init() {
        createModelsDirectoryIfNeeded()
        // Check availability on initialization
        Task {
            await checkAvailability()
        }
    }
    
    // MARK: - Model Availability
    
    /// Check if Apple's on-device model is available
    /// Must be called before attempting inference
    func checkAvailability() async {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            self.isModelAvailable = true
            self.modelStatus = .available
            print("✅ Apple Intelligence model is ready for inference.")
            
        case .unavailable(let reason):
            self.isModelAvailable = false
            
            switch reason {
            case .deviceNotEligible:
                self.modelStatus = .unavailable("Device not eligible for Apple Intelligence")
            case .appleIntelligenceNotEnabled:
                self.modelStatus = .disabled
                print("❌ Apple Intelligence is not enabled in Settings.")
            case .modelNotReady:
                self.modelStatus = .downloading
                print("⏳ Model is still downloading...")
            @unknown default:
                self.modelStatus = .unavailable("Unknown reason")
            }
            
        @unknown default:
            self.isModelAvailable = false
            self.modelStatus = .unavailable("Unknown availability status")
        }
    }
    
    /// List local models (Apple Intelligence + any downloaded external models)
    func listLocalModels() -> [LocalModel] {
        var models: [LocalModel] = []
        
        // Add Apple Intelligence model if available
        if isModelAvailable {
            models.append(LocalModel(
                id: "apple-intelligence",
                name: "Apple Intelligence",
                path: "system",
                size: 0, // System model, size not applicable
                createdAt: Date()
            ))
        }
        
        // List any additional downloaded models
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: modelsDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )
            
            let downloadedModels = contents.compactMap { url -> LocalModel? in
                guard let resources = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                      let size = resources.fileSize,
                      let createdAt = resources.creationDate else {
                    return nil
                }
                
                return LocalModel(
                    id: url.lastPathComponent,
                    name: url.lastPathComponent,
                    path: url.path,
                    size: Int64(size),
                    createdAt: createdAt
                )
            }
            
            models.append(contentsOf: downloadedModels)
        } catch {
            print("Error listing local models: \(error)")
        }
        
        return models
    }
    
    // MARK: - Session Management
    
    /// Get or create a session for a chat
    /// Each chat should have its own session to maintain context
    private func getSession(for chatId: String, systemPrompt: String?) -> LanguageModelSession? {
        guard isModelAvailable else {
            print("❌ Model not available")
            return nil
        }
        
        if let existingSession = sessions[chatId] {
            return existingSession
        }
        
        // Create new session with system prompt
        let instructions = systemPrompt ?? """
        You are a helpful AI assistant running on-device using Apple Intelligence.
        Provide clear, accurate, and concise responses.
        You have access to the user's conversation history within this session.
        """
        
        let session = LanguageModelSession(
            model: .default,
            instructions: instructions
        )
        
        sessions[chatId] = session
        return session
    }
    
    /// Clear session history for a specific chat
    func clearSession(for chatId: String) {
        sessions.removeValue(forKey: chatId)
    }
    
    /// Clear all sessions
    func clearAllSessions() {
        sessions.removeAll()
    }
    
    // MARK: - Inference
    
    /// Generate text using Apple Intelligence (atomic, non-streaming)
    /// Use this for background tasks like summarization
    func generate(
        modelName: String = "apple-intelligence",
        prompt: String,
        chatId: String? = nil,
        systemPrompt: String? = nil
    ) async throws -> String {
        guard isModelAvailable else {
            throw MLXServiceError.modelNotAvailable
        }
        
        let sessionId = chatId ?? UUID().uuidString
        guard let session = getSession(for: sessionId, systemPrompt: systemPrompt) else {
            throw MLXServiceError.sessionCreationFailed
        }
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("❌ Generation failed: \(error.localizedDescription)")
            throw MLXServiceError.inferenceFailed(error.localizedDescription)
        }
    }
    
    /// Stream generation using a local MLX model
    func streamGenerate(
        modelName: String,
        prompt: String,
        maxTokens: Int = 2048,
        temperature: Double = 0.7,
        topP: Double = 0.9
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard isModelAvailable(modelName) else {
                        throw MLXServiceError.modelNotFound(modelName)
                    }
                    
                    // Placeholder for streaming implementation
                    // In a real implementation, you would yield tokens as they're generated
                    
                    throw MLXServiceError.notImplemented
                    
                    /*
                    // Example pseudo-code:
                    let model = try await loadModel(modelName)
                    let tokens = try tokenize(prompt, model: model)
                    
                    for try await token in model.generateStream(tokens: tokens, maxTokens: maxTokens) {
                        let text = try detokenize([token], model: model)
                        continuation.yield(text)
                    }
                    
                    continuation.finish()
                    */
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Chat Interface
    
    /// Chat completion (atomic) - maintains conversation context automatically
    func chat(
        modelName: String = "apple-intelligence",
        messages: [ChatMessage],
        chatId: String,
        systemPrompt: String? = nil
    ) async throws -> String {
        // For Apple Intelligence, we just send the latest user message
        // The session maintains the conversation history
        guard let lastMessage = messages.last else {
            throw MLXServiceError.invalidInput("No messages provided")
        }
        
        return try await generate(
            modelName: modelName,
            prompt: lastMessage.content,
            chatId: chatId,
            systemPrompt: systemPrompt
        )
    }
    
    /// Stream chat completion - maintains conversation context automatically
    func streamChat(
        modelName: String = "apple-intelligence",
        messages: [ChatMessage],
        chatId: String,
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        // For Apple Intelligence, we just send the latest user message
        // The session maintains the conversation history
        guard let lastMessage = messages.last else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: MLXServiceError.invalidInput("No messages provided"))
            }
        }
        
        return streamGenerate(
            modelName: modelName,
            prompt: lastMessage.content,
            chatId: chatId,
            systemPrompt: systemPrompt
        )
    }
    
    // MARK: - Summarization
    
    /// Generate a summary using Apple Intelligence
    func summarize(
        text: String,
        chatId: String? = nil
    ) async throws -> String {
        let prompt = """
        Summarize the following text in 3-5 bullet points:
        
        \(text)
        """
        
        return try await generate(
            prompt: prompt,
            chatId: chatId,
            systemPrompt: "You are a helpful assistant that creates concise summaries."
        )
    }
    
    // MARK: - Embeddings
    
    /// Note: Apple's FoundationModels framework doesn't expose embeddings directly
    /// For embeddings, you would need to use a different approach or wait for API updates
    func createEmbedding(
        modelName: String,
        text: String
    ) async throws -> [Float] {
        // Apple Intelligence doesn't expose embeddings in the current API
        // You would need to use a cloud service or different local model
        throw MLXServiceError.notImplemented
    }
    
    // MARK: - Private Methods
    
    private func createModelsDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
            try? FileManager.default.createDirectory(
                at: modelsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
    
    // MARK: - Model Status
    
    /// Get human-readable status message
    func getStatusMessage() -> String {
        switch modelStatus {
        case .checking:
            return "Checking Apple Intelligence availability..."
        case .available:
            return "Apple Intelligence is ready"
        case .unavailable(let reason):
            return reason
        case .downloading:
            return "Apple Intelligence model is downloading. Please check back later."
        case .disabled:
            return "Apple Intelligence is disabled. Enable it in Settings > Apple Intelligence & Siri."
        }
    }
}

// MARK: - Supporting Types

struct LocalModel: Identifiable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let createdAt: Date
}

struct ChatMessage {
    let role: String
    let content: String
}

// MARK: - Errors

enum MLXServiceError: LocalizedError {
    case modelNotAvailable
    case sessionCreationFailed
    case inferenceFailed(String)
    case invalidInput(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Apple Intelligence model is not available. Please check Settings > Apple Intelligence & Siri."
        case .sessionCreationFailed:
            return "Failed to create language model session"
        case .inferenceFailed(let error):
            return "Inference failed: \(error)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .notImplemented:
            return "This feature is not yet implemented in Apple's FoundationModels framework."
        }
    }
}
