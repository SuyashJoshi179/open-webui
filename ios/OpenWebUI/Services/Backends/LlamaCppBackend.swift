//
//  LlamaCppBackend.swift
//  OpenWebUI
//
//  Backend for Llama.cpp local models
//  Dynamic model backend - users can add local GGUF models
//

import Foundation
import SwiftUI

/// Backend for running quantized LLMs locally using llama.cpp
@MainActor
class LlamaCppBackend: AIBackend, ObservableObject {
    // MARK: - Auto-Registration
    
    static let autoRegister: Void = {
        BackendManager.registerBackendFactory {
            LlamaCppBackend()
        }
    }()
    
    // MARK: - AIBackend Protocol Properties
    
    let id = "llama-cpp"
    let name = "Llama.cpp"
    let description = "Run quantized LLMs locally using llama.cpp. Supports GGUF format models."
    let iconName = "cpu.fill"
    
    var backendSettings: AIBackendSettings {
        get { LlamaCppSettings() }
        set { }
    }
    
    // MARK: - Private Properties
    
    @Published private var models: [ConfiguredAIModel] = []
    
    // MARK: - AIBackend Protocol - Model Management
    
    func getConfiguredModels() -> [ConfiguredAIModel] {
        return models
    }
    
    func addModel(_ config: ModelConfiguration) throws -> ConfiguredAIModel {
        guard let modelPath = config.modelPath, !modelPath.isEmpty else {
            throw BackendError.invalidConfiguration("Model path is required")
        }
        
        let model = ConfiguredAIModel(
            id: UUID(),
            backendId: id,
            displayName: config.displayName ?? "Local Model",
            modelIdentifier: modelPath,
            configuration: config,
            capabilities: ModelCapabilities(
                supportsStreaming: true,
                supportsVision: false,
                supportsFunctionCalling: false,
                maxContextLength: config.contextSize ?? 4096,
                maxOutputTokens: 2048
            )
        )
        
        models.append(model)
        return model
    }
    
    func removeModel(_ modelId: UUID) throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        models.remove(at: index)
    }
    
    func updateModel(_ modelId: UUID, config: ModelConfiguration) throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        var updatedModel = models[index]
        updatedModel.configuration = config
        models[index] = updatedModel
    }
    
    func supportsModelAddition() -> Bool { true }
    func supportsModelRemoval() -> Bool { true }
    
    // MARK: - AIBackend Protocol - Operations
    
    func initialize() async throws {
        // TODO: Initialize llama.cpp library
    }
    
    func streamGenerate(modelId: UUID, prompt: String, context: AIContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: BackendError.operationNotSupported)
        }
    }
    
    func cleanup() async { }
}

struct LlamaCppSettings: AIBackendSettings {
    let backendId = "llama-cpp"
    
    mutating func resetToDefaults() {
        // No settings to reset
    }
    
    func settingsView() -> AnyView {
        AnyView(Text("Llama.cpp - Coming Soon"))
    }
    
    func validate() -> Result<Void, SettingsError> {
        .success(())
    }
}
