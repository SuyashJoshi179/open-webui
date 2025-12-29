//
//  LiteRTBackend.swift
//  OpenWebUI
//
//  Backend for TensorFlow Lite models
//  Dynamic model backend - users can add TFLite models
//

import Foundation
import SwiftUI

/// Backend for running TensorFlow Lite models on-device
@MainActor
class LiteRTBackend: AIBackend, ObservableObject {
    // MARK: - Auto-Registration
    
    static let autoRegister: Void = {
        BackendManager.registerBackendFactory {
            LiteRTBackend()
        }
    }()
    
    // MARK: - AIBackend Protocol Properties
    
    let id = "litert"
    let name = "LiteRT"
    let description = "Run TensorFlow Lite models on-device. Optimized for mobile inference."
    let iconName = "cube.fill"
    
    var backendSettings: AIBackendSettings {
        get { LiteRTSettings() }
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
            displayName: config.displayName ?? "TFLite Model",
            modelIdentifier: modelPath,
            configuration: config,
            capabilities: ModelCapabilities(
                supportsStreaming: false,
                supportsVision: false,
                supportsFunctionCalling: false,
                maxContextLength: 2048,
                maxOutputTokens: 1024
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
        // TODO: Initialize TFLite runtime
    }
    
    func streamGenerate(modelId: UUID, prompt: String, context: AIContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: BackendError.operationNotSupported)
        }
    }
    
    func cleanup() async { }
}

struct LiteRTSettings: AIBackendSettings {
    let backendId = "litert"
    
    mutating func resetToDefaults() {
        // No settings to reset
    }
    
    func settingsView() -> AnyView {
        AnyView(Text("LiteRT - Coming Soon"))
    }
    
    func validate() -> Result<Void, SettingsError> {
        .success(())
    }
}
