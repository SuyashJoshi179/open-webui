//
//  OpenAICompatibleBackend.swift
//  OpenWebUI
//
//  Backend for OpenAI-compatible APIs
//  Dynamic model backend - users can add/remove/configure multiple models
//

import Foundation
import SwiftUI

/// Backend for OpenAI-compatible API endpoints
/// Supports multiple user-configured models
@MainActor
class OpenAICompatibleBackend: AIBackend, ObservableObject {
    // MARK: - Auto-Registration
    
    static let autoRegister: Void = {
        BackendManager.registerBackendFactory {
            OpenAICompatibleBackend()
        }
    }()
    
    // MARK: - AIBackend Protocol Properties
    
    let id = "openai-compatible"
    let name = "OpenAI Compatible"
    let description = "Connect to OpenAI, Ollama, or any OpenAI-compatible API endpoint"
    let iconName = "cloud.fill"
    
    var backendSettings: AIBackendSettings {
        get { OpenAICompatibleSettings() }
        set { /* Settings managed per-model */ }
    }
    
    // MARK: - Private Properties
    
    @Published private var models: [ConfiguredAIModel] = []
    private let persistenceKey = "openai_compatible_models"
    
    // MARK: - Initialization
    
    init() {
        loadModels()
    }
    
    // MARK: - AIBackend Protocol - Model Management
    
    func getConfiguredModels() -> [ConfiguredAIModel] {
        return models
    }
    
    func addModel(_ config: ModelConfiguration) throws -> ConfiguredAIModel {
        // Validate configuration
        guard let apiURL = config.apiURL, !apiURL.isEmpty else {
            throw BackendError.invalidConfiguration("API URL is required")
        }
        
        // Create new model
        let model = ConfiguredAIModel(
            id: UUID(),
            backendId: id,
            displayName: config.displayName ?? "Custom Model",
            modelIdentifier: config.modelIdentifier ?? "gpt-3.5-turbo",
            configuration: config,
            capabilities: ModelCapabilities(
                supportsStreaming: true,
                supportsVision: false,
                supportsFunctionCalling: false,
                maxContextLength: 4096,
                maxOutputTokens: 2048,
                supportsEmbeddings: false
            )
        )
        
        models.append(model)
        saveModels()
        
        return model
    }
    
    func removeModel(_ modelId: UUID) throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        models.remove(at: index)
        saveModels()
    }
    
    func updateModel(_ modelId: UUID, config: ModelConfiguration) throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        
        // Update configuration
        var updatedModel = models[index]
        updatedModel.configuration = config
        models[index] = updatedModel
        
        saveModels()
    }
    
    func supportsModelAddition() -> Bool {
        return true
    }
    
    func supportsModelRemoval() -> Bool {
        return true
    }
    
    // MARK: - AIBackend Protocol - Operations
    
    func initialize() async throws {
        // Nothing to initialize for API-based backend
    }
    
    func streamGenerate(
        modelId: UUID,
        prompt: String,
        context: AIContext
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let model = models.first(where: { $0.id == modelId }) else {
                    continuation.finish(throwing: BackendError.modelNotFound)
                    return
                }
                
                guard let apiURL = model.configuration.apiURL else {
                    continuation.finish(throwing: BackendError.invalidConfiguration("API URL not configured"))
                    return
                }
                
                do {
                    // Build request
                    guard let url = URL(string: apiURL) else {
                        continuation.finish(throwing: BackendError.invalidConfiguration("Invalid API URL"))
                        return
                    }
                    
                    let endpoint = url.appendingPathComponent("/chat/completions")
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    if let apiKey = model.configuration.apiKey, !apiKey.isEmpty {
                        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    
                    if let orgId = model.configuration.organizationId, !orgId.isEmpty {
                        request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
                    }
                    
                    // Build messages
                    var messages: [[String: String]] = []
                    if let systemPrompt = context.systemPrompt {
                        messages.append(["role": "system", "content": systemPrompt])
                    }
                    for msg in context.conversationHistory {
                        messages.append(["role": msg.role, "content": msg.content])
                    }
                    messages.append(["role": "user", "content": prompt])
                    
                    // Build request body
                    let requestBody: [String: Any] = [
                        "model": model.modelIdentifier,
                        "messages": messages,
                        "stream": true,
                        "temperature": model.configuration.temperature,
                        "max_tokens": model.configuration.maxTokens,
                        "top_p": model.configuration.topP
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    // Make streaming request
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: BackendError.networkError("Invalid response"))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: BackendError.networkError("HTTP \(httpResponse.statusCode)"))
                        return
                    }
                    
                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            
                            if data == "[DONE]" {
                                break
                            }
                            
                            if let jsonData = data.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(content)
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: BackendError.generationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func cleanup() async {
        // Nothing to clean up for API-based backend
    }
    
    // MARK: - Persistence
    
    private func saveModels() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(models) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }
    
    private func loadModels() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let loaded = try? JSONDecoder().decode([ConfiguredAIModel].self, from: data) else {
            return
        }
        models = loaded
    }
}

/// Settings for OpenAI Compatible backend
struct OpenAICompatibleSettings: AIBackendSettings {
    let backendId = "openai-compatible"
    
    mutating func resetToDefaults() {
        // No settings to reset
    }
    
    func settingsView() -> AnyView {
        AnyView(
            VStack(spacing: 16) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("OpenAI Compatible API")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Connect to OpenAI, Ollama, or any OpenAI-compatible API endpoint. Add models with their API URLs and keys.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Tap '+' to add a new model")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        )
    }
    
    func validate() -> Result<Void, SettingsError> {
        return .success(())
    }
}


