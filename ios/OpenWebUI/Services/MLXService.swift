//
//  MLXService.swift
//  OpenWebUI
//
//  Local inference service using Apple Intelligence
//  Uses FoundationModels framework (iOS 18+)
//

import Foundation
import FoundationModels

@MainActor
@available(iOS 26.0, *)
class MLXService: ObservableObject {
    static let shared = MLXService()
    
    @Published var isModelAvailable: Bool = false
    @Published var modelStatus: ModelAvailabilityStatus = .checking
    
    private let modelsDirectory = AppConfig.modelsDirectory
    
    // FoundationModels sessions for maintaining context
    private var sessions: [String: LanguageModelSession] = [:]
    
    enum ModelAvailabilityStatus: Equatable {
        case checking
        case available
        case unavailable(String)
        case downloading
        case disabled
    }
    
    private init() {
        createModelsDirectoryIfNeeded()
        // Check availability synchronously on init
        checkAvailabilitySync()
    }
    
    // MARK: - Model Availability
    
    /// Check if Apple's on-device model is available (synchronous)
    func checkAvailabilitySync() {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            self.isModelAvailable = true
            self.modelStatus = .available
            print("✅ Apple Intelligence is available")
            
        case .unavailable(let reason):
            self.isModelAvailable = false
            switch reason {
            case .deviceNotEligible:
                self.modelStatus = .unavailable("Device not eligible for Apple Intelligence")
            case .appleIntelligenceNotEnabled:
                self.modelStatus = .unavailable("Apple Intelligence not enabled in Settings")
            case .modelNotReady:
                self.modelStatus = .downloading
            @unknown default:
                self.modelStatus = .unavailable("Apple Intelligence unavailable")
            }
            print("❌ Apple Intelligence unavailable: \(reason)")
        }
    }
    
    /// Check if Apple's on-device model is available (async version for updates)
    func checkAvailability() async {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            self.isModelAvailable = true
            self.modelStatus = .available
            print("✅ Apple Intelligence is available")
            
        case .unavailable(let reason):
            self.isModelAvailable = false
            switch reason {
            case .deviceNotEligible:
                self.modelStatus = .unavailable("Device not eligible for Apple Intelligence")
            case .appleIntelligenceNotEnabled:
                self.modelStatus = .unavailable("Apple Intelligence not enabled in Settings")
            case .modelNotReady:
                self.modelStatus = .downloading
            @unknown default:
                self.modelStatus = .unavailable("Apple Intelligence unavailable")
            }
            print("❌ Apple Intelligence unavailable: \(reason)")
        }
    }
    
    /// List local models
    func listLocalModels() -> [LocalModel] {
        var models: [LocalModel] = []
        
        // Add Apple Intelligence as the primary on-device model if available
        if isModelAvailable {
            models.append(LocalModel(
                id: "apple-intelligence",
                name: "Apple Intelligence (On-Device)",
                path: "",
                size: 0,
                createdAt: Date()
            ))
        }
        
        // List any downloaded models in the models directory
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
    private func getSession(for chatId: String, systemPrompt: String? = nil) -> LanguageModelSession? {
        if let existingSession = sessions[chatId] {
            return existingSession
        }
        
        // Create new session
        let instructions = systemPrompt ?? "You are a helpful AI assistant. Be concise and accurate."
        
        do {
            let session = try LanguageModelSession(
                model: .default,
                instructions: instructions
            )
            sessions[chatId] = session
            return session
        } catch {
            print("❌ Failed to create session: \(error)")
            return nil
        }
    }
    
    /// Clear session for specific chat
    func clearSession(for chatId: String) {
        sessions.removeValue(forKey: chatId)
    }
    
    /// Clear all sessions
    func clearAllSessions() {
        sessions.removeAll()
    }
    
    // MARK: - Inference
    
    /// Generate text (stub - requires iOS 26+)
    func generate(
        modelName: String = "apple-intelligence",
        prompt: String,
        chatId: String? = nil,
        systemPrompt: String? = nil
    ) async throws -> String {
        throw MLXServiceError.modelNotAvailable
    }
    
    /// Stream generation with Apple Intelligence
    func streamGenerate(
        modelName: String,
        prompt: String,
        chatId: String,
        maxTokens: Int = 2048,
        temperature: Double = 0.7,
        topP: Double = 0.9
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard isModelAvailable else {
                    continuation.finish(throwing: MLXServiceError.modelNotAvailable)
                    return
                }
                
                // Get or create session for this chat to maintain context
                guard let session = getSession(for: chatId) else {
                    continuation.finish(throwing: MLXServiceError.sessionCreationFailed)
                    return
                }
                
                do {
                    let stream = session.streamResponse(to: prompt)
                    
                    var previousContent = ""
                    for try await part in stream {
                        // Calculate delta by comparing with previous content
                        let currentContent = part.content
                        if currentContent.hasPrefix(previousContent) {
                            let delta = String(currentContent.dropFirst(previousContent.count))
                            if !delta.isEmpty {
                                continuation.yield(delta)
                            }
                        } else {
                            // Fallback: yield the whole part if not incremental
                            continuation.yield(currentContent)
                        }
                        previousContent = currentContent
                    }
                    
                    continuation.finish()
                    
                    // Don't clear session - keep it for context
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Chat Interface
    
    /// Chat completion (stub - requires iOS 26+)
    func chat(
        modelName: String = "apple-intelligence",
        messages: [MLXChatMessage],
        chatId: String,
        systemPrompt: String? = nil
    ) async throws -> String {
        throw MLXServiceError.modelNotAvailable
    }
    
    /// Stream chat completion (stub - requires iOS 26+)
    func streamChat(
        modelName: String = "apple-intelligence",
        messages: [MLXChatMessage],
        chatId: String,
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: MLXServiceError.modelNotAvailable)
        }
    }
    
    // MARK: - Summarization
    
    /// Generate a summary (stub - requires iOS 26+)
    func summarize(
        text: String,
        chatId: String? = nil
    ) async throws -> String {
        throw MLXServiceError.modelNotAvailable
    }
    
    // MARK: - Embeddings
    
    /// Create embedding (stub - not available)
    func createEmbedding(
        modelName: String,
        text: String
    ) async throws -> [Float] {
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

struct MLXChatMessage {
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
    case modelNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Apple Intelligence requires iOS 26 or later."
        case .sessionCreationFailed:
            return "Failed to create language model session"
        case .inferenceFailed(let error):
            return "Inference failed: \(error)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .notImplemented:
            return "This feature is not yet implemented."
        case .modelNotFound(let name):
            return "Model not found: \(name)"
        }
    }
}
