//
//  AppleFoundationBackend.swift
//  OpenWebUI
//
//  Apple Intelligence backend using FoundationModels framework (iOS 26+)
//

import Foundation
import FoundationModels
import SwiftUI

@MainActor
@available(iOS 26.0, *)
class AppleFoundationBackend: AIBackend, ObservableObject {
    // MARK: - AIBackend Protocol Properties
    
    let id = "apple-foundation"
    let name = "Apple Intelligence"
    let description = "On-device AI using Apple's Foundation Models. Private, secure, and no API key required."
    let iconName = "apple.logo"
    
    @Published var isAvailable: Bool = false
    var settings: AIBackendSettings {
        get { _settings }
        set { _settings = newValue as! AppleFoundationSettings }
    }
    
    // MARK: - Private Properties
    
    private var _settings = AppleFoundationSettings()
    private let modelsDirectory = AppConfig.modelsDirectory
    
    // FoundationModels sessions for maintaining context
    private var sessions: [String: LanguageModelSession] = [:]
    
    @Published private(set) var modelStatus: ModelAvailabilityStatus = .checking
    
    enum ModelAvailabilityStatus: Equatable {
        case checking
        case available
        case unavailable(String)
        case downloading
        case disabled
    }
    
    // MARK: - Initialization
    
    init() {
        createModelsDirectoryIfNeeded()
        // Check availability synchronously on init
        checkAvailabilitySync()
    }
    
    // MARK: - AIBackend Protocol Methods
    
    func initialize() async throws {
        await checkAvailability()
        
        if !isAvailable {
            throw BackendError.notAvailable
        }
    }
    
    func checkAvailability() async -> Bool {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            self.isAvailable = true
            self.modelStatus = .available
            print("✅ Apple Intelligence is available")
            return true
            
        case .unavailable(let reason):
            self.isAvailable = false
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
            return false
        }
    }
    
    func listModels() async throws -> [AIModel] {
        var models: [AIModel] = []
        
        // Add Apple Intelligence as the primary on-device model if available
        if isAvailable {
            let appleModel = AIModel(
                id: "apple-intelligence",
                name: "Apple Intelligence",
                backendId: id,
                description: "On-device AI model",
                capabilities: ModelCapabilities(
                    supportsStreaming: true,
                    supportsVision: false,
                    supportsFunctionCalling: false,
                    maxContextLength: 8192,
                    maxOutputTokens: 2048
                ),
                metadata: ModelMetadata(
                    size: nil,
                    family: "Apple Foundation",
                    version: "1.0"
                )
            )
            models.append(appleModel)
        }
        
        // List any downloaded models in the models directory
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: modelsDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
            )
            
            let downloadedModels = contents.compactMap { url -> AIModel? in
                guard let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
                      let size = resources.fileSize else {
                    return nil
                }
                
                return AIModel(
                    id: url.lastPathComponent,
                    name: url.lastPathComponent,
                    backendId: id,
                    description: "Downloaded model",
                    capabilities: .default,
                    metadata: ModelMetadata(
                        size: Int64(size)
                    )
                )
            }
            
            models.append(contentsOf: downloadedModels)
        } catch {
            print("Error listing local models: \(error)")
        }
        
        return models
    }
    
    func streamGenerate(
        model: String,
        prompt: String,
        context: AIContext,
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard isAvailable else {
                    continuation.finish(throwing: BackendError.notAvailable)
                    return
                }
                
                // Get or create session for this chat to maintain context
                guard let session = getSession(
                    for: context.chatId,
                    systemPrompt: context.systemPrompt
                ) else {
                    continuation.finish(throwing: BackendError.initializationFailed("Failed to create session"))
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
                    continuation.finish(throwing: BackendError.generationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func cleanup() async {
        clearAllSessions()
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
    
    // MARK: - Private Helpers
    
    /// Check if Apple's on-device model is available (synchronous)
    private func checkAvailabilitySync() {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            self.isAvailable = true
            self.modelStatus = .available
            print("✅ Apple Intelligence is available")
            
        case .unavailable(let reason):
            self.isAvailable = false
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

// MARK: - AppleFoundationSettings

struct AppleFoundationSettings: AIBackendSettings {
    var backendId: String = "apple-foundation"
    
    // Apple Intelligence has minimal settings (mostly automatic)
    var keepSessionsInMemory: Bool = true
    var maxConcurrentSessions: Int = 5
    
    func settingsView() -> AnyView {
        AnyView(AppleFoundationSettingsView(settings: self))
    }
    
    func validate() -> Result<Void, SettingsError> {
        // Validate max concurrent sessions
        if maxConcurrentSessions < 1 || maxConcurrentSessions > 20 {
            return .failure(.invalidValue(field: "maxConcurrentSessions", reason: "Must be between 1 and 20"))
        }
        
        return .success(())
    }
    
    mutating func resetToDefaults() {
        keepSessionsInMemory = true
        maxConcurrentSessions = 5
    }
}

// MARK: - AppleFoundationSettingsView

struct AppleFoundationSettingsView: View {
    @State var settings: AppleFoundationSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                Text("Apple Intelligence runs on-device and requires no configuration. Your data stays private and secure on your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Label("About", systemImage: "info.circle")
            }
            
            Section {
                Toggle("Keep Sessions in Memory", isOn: $settings.keepSessionsInMemory)
                
                Stepper(
                    "Max Concurrent Sessions: \(settings.maxConcurrentSessions)",
                    value: $settings.maxConcurrentSessions,
                    in: 1...20
                )
            } header: {
                Label("Performance", systemImage: "gauge.with.dots.needle.67percent")
            } footer: {
                Text("Keeping sessions in memory maintains conversation context but uses more RAM. Max concurrent sessions limits how many active conversations can run simultaneously.")
            }
            
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundStyle(.red)
            }
            
            Section {
                Button("Save") {
                    saveSettings()
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            }
        }
        .navigationTitle("Apple Intelligence Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveSettings() {
        do {
            try BackendSettingsManager.shared.saveSettings(settings)
            dismiss()
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
}

// Note: MLXService compatibility wrapper is kept in the original MLXService.swift file
// to avoid breaking existing code that imports it directly
