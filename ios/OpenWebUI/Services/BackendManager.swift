//
//  BackendManager.swift
//  OpenWebUI
//
//  Central manager for AI backends in model-centric architecture.
//  Aggregates models from all backends and provides unified access.
//

import Foundation
import SwiftUI

/// Manages all AI backends and provides unified access to models
@MainActor
class BackendManager: ObservableObject {
    static let shared = BackendManager()
    
    // MARK: - Published Properties
    
    /// All configured models from all backends
    @Published private(set) var allModels: [ConfiguredAIModel] = []
    
    /// Currently selected model for generation
    @Published var activeModel: ConfiguredAIModel?
    
    /// All registered backends
    @Published private(set) var backends: [any AIBackend] = []
    
    /// Whether initialization is in progress
    @Published private(set) var isInitializing = false
    
    /// Current error, if any
    @Published var error: BackendError?
    
    // MARK: - Private Properties
    
    private var backendRegistry: [String: any AIBackend] = [:]
    private let userDefaults = UserDefaults.standard
    private let activeModelKey = "active_model_id"
    
    // MARK: - Auto-Discovery Registry
    
    /// Static registry for backend factories (Spring Boot-style component scanning)
    private static var backendFactories: [@MainActor () -> (any AIBackend)?] = []
    
    /// Register a backend factory for auto-discovery
    public static func registerBackendFactory(_ factory: @escaping @MainActor () -> (any AIBackend)?) {
        backendFactories.append(factory)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Trigger auto-registration
        Self.triggerAutoRegistration()
        
        // Discover and register all backends
        discoverAndRegisterBackends()
        
        // Refresh model list
        refreshModels()
        
        // Load saved active model
        loadSavedActiveModel()
        
        // Initialize all backends in background
        Task {
            await initializeAllBackends()
            print("✅ All backends initialized, \(allModels.count) models available")
        }
    }
    
    /// Trigger static auto-registration properties
    private static func triggerAutoRegistration() {
        if #available(iOS 26.0, *) {
            _ = AppleFoundationBackend.autoRegister
        }
        _ = OpenAICompatibleBackend.autoRegister
        _ = LlamaCppBackend.autoRegister
        _ = LiteRTBackend.autoRegister
    }
    
    /// Discover and register all backends automatically
    private func discoverAndRegisterBackends() {
        for factory in Self.backendFactories {
            if let backend = factory() {
                registerBackend(backend)
            }
        }
    }
    
    // MARK: - Backend Management
    
    /// Register a new backend
    func registerBackend(_ backend: any AIBackend) {
        guard backendRegistry[backend.id] == nil else {
            print("⚠️ Backend \(backend.id) already registered")
            return
        }
        
        backendRegistry[backend.id] = backend
        backends.append(backend)
        
        print("✅ Registered backend: \(backend.name)")
        
        // Refresh models to include this backend's models
        refreshModels()
    }
    
    /// Get backend by ID
    func getBackend(id: String) -> (any AIBackend)? {
        return backendRegistry[id]
    }
    
    /// Initialize all backends
    func initializeAllBackends() async {
        isInitializing = true
        defer { isInitializing = false }
        
        for backend in backends {
            do {
                try await backend.initialize()
                print("✅ Initialized \(backend.name)")
            } catch {
                print("❌ Failed to initialize \(backend.name): \(error)")
            }
        }
        
        // Refresh models after initialization
        refreshModels()
    }
    
    // MARK: - Model Management
    
    /// Refresh the list of all models from all backends
    func refreshModels() {
        allModels = backends.flatMap { $0.getConfiguredModels() }
        objectWillChange.send()
    }
    
    /// Add a new model to a backend
    /// - Parameters:
    ///   - backendId: ID of the backend to add the model to
    ///   - config: Configuration for the new model
    /// - Returns: The newly created model
    /// - Throws: BackendError if the backend doesn't exist or doesn't support adding models
    func addModel(to backendId: String, config: ModelConfiguration) throws -> ConfiguredAIModel {
        guard let backend = backendRegistry[backendId] else {
            throw BackendError.backendNotFound
        }
        
        guard backend.supportsModelAddition() else {
            throw BackendError.operationNotSupported
        }
        
        let model = try backend.addModel(config)
        refreshModels()
        return model
    }
    
    /// Remove a model
    /// - Parameter modelId: ID of the model to remove
    /// - Throws: BackendError if the model doesn't exist or can't be removed
    func removeModel(_ modelId: UUID) throws {
        guard let model = allModels.first(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        
        guard let backend = backendRegistry[model.backendId] else {
            throw BackendError.backendNotFound
        }
        
        guard backend.supportsModelRemoval() else {
            throw BackendError.operationNotSupported
        }
        
        try backend.removeModel(modelId)
        
        // If this was the active model, clear selection
        if activeModel?.id == modelId {
            activeModel = nil
            userDefaults.removeObject(forKey: activeModelKey)
        }
        
        refreshModels()
    }
    
    /// Update a model's configuration
    /// - Parameters:
    ///   - modelId: ID of the model to update
    ///   - config: New configuration
    /// - Throws: BackendError if the model doesn't exist
    func updateModel(_ modelId: UUID, config: ModelConfiguration) throws {
        guard let model = allModels.first(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        
        guard let backend = backendRegistry[model.backendId] else {
            throw BackendError.backendNotFound
        }
        
        try backend.updateModel(modelId, config: config)
        refreshModels()
    }
    
    // MARK: - Model Selection
    
    /// Select a model as the active model for generation
    /// - Parameter model: The model to select
    func selectModel(_ model: ConfiguredAIModel) {
        activeModel = model
        saveActiveModelId(model.id)
        objectWillChange.send()
        print("✅ Selected model: \(model.displayName)")
    }
    
    /// Select a model by ID
    /// - Parameter modelId: ID of the model to select
    /// - Throws: BackendError if the model doesn't exist
    func selectModel(id modelId: UUID) throws {
        guard let model = allModels.first(where: { $0.id == modelId }) else {
            throw BackendError.modelNotFound
        }
        selectModel(model)
    }
    
    /// Get models grouped by backend
    func getModelsGroupedByBackend() -> [(backend: any AIBackend, models: [ConfiguredAIModel])] {
        var grouped: [(backend: any AIBackend, models: [ConfiguredAIModel])] = []
        
        for backend in backends {
            let backendModels = backend.getConfiguredModels()
            if !backendModels.isEmpty {
                grouped.append((backend: backend, models: backendModels))
            }
        }
        
        return grouped
    }
    
    // MARK: - Generation Operations
    
    /// Stream generate text using the active model
    /// - Parameters:
    ///   - prompt: Input prompt
    ///   - context: Additional context
    /// - Returns: Async stream of text chunks
    func streamGenerate(
        prompt: String,
        context: AIContext = AIContext(chatId: UUID().uuidString)
    ) -> AsyncThrowingStream<String, Error> {
        guard let model = activeModel else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: BackendError.noActiveModel)
            }
        }
        
        guard let backend = backendRegistry[model.backendId] else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: BackendError.backendNotFound)
            }
        }
        
        return backend.streamGenerate(
            modelId: model.id,
            prompt: prompt,
            context: context
        )
    }
    
    // MARK: - Persistence
    
    private func saveActiveModelId(_ modelId: UUID) {
        userDefaults.set(modelId.uuidString, forKey: activeModelKey)
    }
    
    private func loadSavedActiveModel() {
        guard let savedId = userDefaults.string(forKey: activeModelKey),
              let uuid = UUID(uuidString: savedId),
              let model = allModels.first(where: { $0.id == uuid }) else {
            // No saved model or model no longer exists, select first available
            activeModel = allModels.first
            return
        }
        
        activeModel = model
    }
}
