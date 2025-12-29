//
//  AppleFoundationBackend.swift
//  OpenWebUI
//
//  Backend for Apple Intelligence (Foundation Models)
//  Fixed model backend - provides single default model
//

import Foundation
import SwiftUI
import FoundationModels

/// Backend for Apple's on-device Foundation Models (Apple Intelligence)
/// This backend provides a single fixed model that cannot be added or removed
@MainActor
@available(iOS 26.0, *)
class AppleFoundationBackend: AIBackend, ObservableObject {
    // MARK: - Auto-Registration (Spring Boot style)
    
    static let autoRegister: Void = {
        if #available(iOS 26.0, *) {
            BackendManager.registerBackendFactory {
                AppleFoundationBackend()
            }
        }
    }()
    
    // MARK: - AIBackend Protocol Properties
    
    let id = "apple-foundation"
    let name = "Apple Intelligence"
    let description = "On-device AI using Apple's Foundation Models. Private, secure, and no API key required."
    let iconName = "apple.logo"
    
    var backendSettings: AIBackendSettings {
        get { AppleFoundationSettings() }
        set { /* No settings for Apple Intelligence */ }
    }
    
    // MARK: - Private Properties
    
    /// Fixed model ID for Apple Intelligence
    private let defaultModelId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    
    /// Language model sessions for maintaining context
    @available(iOS 26.0, *)
    private var sessions: [String: LanguageModelSession] = [:]
    
    /// Model availability status
    @Published private(set) var modelStatus: ModelAvailabilityStatus = .checking
    
    enum ModelAvailabilityStatus: Equatable {
        case checking
        case available
        case unavailable(String)
    }
    
    // MARK: - Initialization
    
    init() {
        checkAvailabilitySync()
    }
    
    // MARK: - AIBackend Protocol - Model Management
    
    func getConfiguredModels() -> [ConfiguredAIModel] {
        // Only return model if Apple Intelligence is actually available
        guard SystemLanguageModel.default.availability == .available else {
            return []
        }
        
        return [ConfiguredAIModel(
            id: defaultModelId,
            backendId: id,
            displayName: "Apple Intelligence",
            modelIdentifier: "apple-intelligence-default",
            configuration: ModelConfiguration(), // No configuration needed
            capabilities: ModelCapabilities(
                supportsStreaming: true,
                supportsVision: false,
                supportsFunctionCalling: false,
                maxContextLength: 8192,
                maxOutputTokens: 4096,
                supportsEmbeddings: false
            )
        )]
    }
    
    func addModel(_ config: ModelConfiguration) throws -> ConfiguredAIModel {
        throw BackendError.operationNotSupported
    }
    
    func removeModel(_ modelId: UUID) throws {
        throw BackendError.operationNotSupported
    }
    
    func updateModel(_ modelId: UUID, config: ModelConfiguration) throws {
        throw BackendError.operationNotSupported
    }
    
    func supportsModelAddition() -> Bool {
        return false
    }
    
    func supportsModelRemoval() -> Bool {
        return false
    }
    
    // MARK: - AIBackend Protocol - Operations
    
    func initialize() async throws {
        checkAvailabilitySync()
        
        guard modelStatus == .available else {
            throw BackendError.notAvailable
        }
    }
    
    func streamGenerate(
        modelId: UUID,
        prompt: String,
        context: AIContext
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard modelId == defaultModelId else {
                    continuation.finish(throwing: BackendError.modelNotFound)
                    return
                }
                
                guard SystemLanguageModel.default.availability == .available else {
                    continuation.finish(throwing: BackendError.notAvailable)
                    return
                }
                
                // Get or create session for this chat
                guard let session = getSession(for: context.chatId, systemPrompt: context.systemPrompt) else {
                    continuation.finish(throwing: BackendError.initializationFailed("Failed to create session"))
                    return
                }
                
                do {
                    let stream = session.streamResponse(to: prompt)
                    
                    var previousContent = ""
                    for try await part in stream {
                        // Calculate delta
                        let currentContent = part.content
                        if currentContent.hasPrefix(previousContent) {
                            let delta = String(currentContent.dropFirst(previousContent.count))
                            if !delta.isEmpty {
                                continuation.yield(delta)
                            }
                        } else {
                            // Fallback: yield the whole part
                            continuation.yield(currentContent)
                        }
                        previousContent = currentContent
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: BackendError.generationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func cleanup() async {
        sessions.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Check availability synchronously
    private func checkAvailabilitySync() {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            modelStatus = .available
            print("✅ Apple Intelligence is available")
            
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                modelStatus = .unavailable("Device not eligible for Apple Intelligence")
            case .appleIntelligenceNotEnabled:
                modelStatus = .unavailable("Apple Intelligence not enabled in Settings")
            case .modelNotReady:
                modelStatus = .unavailable("Apple Intelligence model is downloading")
            @unknown default:
                modelStatus = .unavailable("Apple Intelligence unavailable")
            }
            print("❌ Apple Intelligence unavailable: \(reason)")
        }
    }
    
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
}

/// Settings for Apple Foundation backend (empty as it has no configurable settings)
struct AppleFoundationSettings: AIBackendSettings {
    let backendId = "apple-foundation"
    
    mutating func resetToDefaults() {
        // No settings to reset
    }
    
    func settingsView() -> AnyView {
        AnyView(
            VStack(spacing: 16) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Apple Intelligence")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("On-device AI powered by Apple's Foundation Models. Private, secure, and no configuration required.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if #available(iOS 26.0, *) {
                    let status = SystemLanguageModel.default.availability
                    if case .available = status {
                        Label("Ready to use", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Enable Apple Intelligence in Settings", systemImage: "info.circle")
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
        )
    }
    
    func validate() -> Result<Void, SettingsError> {
        return .success(())
    }
}
