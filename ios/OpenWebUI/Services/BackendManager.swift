//
//  BackendManager.swift
//  OpenWebUI
//
//  Central manager for all AI backends
//

import Foundation
import SwiftUI

/// Manages all available AI backends and coordinates their lifecycle
@MainActor
class BackendManager: ObservableObject {
    static let shared = BackendManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var availableBackends: [AIBackend] = []
    @Published var activeBackend: AIBackend?
    @Published private(set) var isInitializing = false
    @Published var error: BackendError?
    
    // MARK: - Private Properties
    
    private var backendRegistry: [String: AIBackend] = [:]
    private let settingsManager = BackendSettingsManager.shared
    private let userDefaults = UserDefaults.standard
    private let activeBackendKey = "active_backend_id"
    
    // MARK: - Initialization
    
    private init() {
        loadSavedActiveBackend()
    }
    
    // MARK: - Backend Registration
    
    /// Register a new backend with the manager
    /// - Parameter backend: The backend to register
    func registerBackend(_ backend: AIBackend) {
        guard backendRegistry[backend.id] == nil else {
            print("⚠️ Backend \(backend.id) already registered")
            return
        }
        
        backendRegistry[backend.id] = backend
        availableBackends.append(backend)
        
        print("✅ Registered backend: \(backend.name)")
        
        // Initialize the backend in the background
        Task {
            await initializeBackend(backend)
        }
    }
    
    /// Unregister a backend
    /// - Parameter backendId: ID of the backend to unregister
    func unregisterBackend(_ backendId: String) {
        guard let backend = backendRegistry[backendId] else { return }
        
        Task {
            await backend.cleanup()
        }
        
        backendRegistry.removeValue(forKey: backendId)
        availableBackends.removeAll { $0.id == backendId }
        
        if activeBackend?.id == backendId {
            activeBackend = nil
        }
    }
    
    // MARK: - Backend Management
    
    /// Get a backend by its ID
    /// - Parameter id: The backend ID
    /// - Returns: The backend if found
    func getBackend(id: String) -> AIBackend? {
        return backendRegistry[id]
    }
    
    /// Set the active backend
    /// - Parameter backendId: ID of the backend to activate
    func setActiveBackend(_ backendId: String) async throws {
        guard let backend = backendRegistry[backendId] else {
            throw BackendError.notAvailable
        }
        
        // Check if backend is available
        let isAvailable = await backend.checkAvailability()
        guard isAvailable else {
            throw BackendError.notAvailable
        }
        
        // Initialize if needed
        if !backend.isAvailable {
            try await backend.initialize()
        }
        
        // Set as active
        activeBackend = backend
        userDefaults.set(backendId, forKey: activeBackendKey)
        
        print("✅ Active backend set to: \(backend.name)")
    }
    
    /// Get all available models across all backends
    /// - Returns: Array of all available models
    func getAllModels() async throws -> [AIModel] {
        var allModels: [AIModel] = []
        
        for backend in availableBackends where backend.isAvailable {
            do {
                let models = try await backend.listModels()
                allModels.append(contentsOf: models)
            } catch {
                print("⚠️ Failed to load models from \(backend.name): \(error)")
            }
        }
        
        return allModels
    }
    
    /// Get models for a specific backend
    /// - Parameter backendId: The backend ID
    /// - Returns: Array of models for that backend
    func getModels(for backendId: String) async throws -> [AIModel] {
        guard let backend = backendRegistry[backendId] else {
            throw BackendError.notAvailable
        }
        
        return try await backend.listModels()
    }
    
    // MARK: - Initialization
    
    /// Initialize a specific backend
    /// - Parameter backend: The backend to initialize
    private func initializeBackend(_ backend: AIBackend) async {
        do {
            let isAvailable = await backend.checkAvailability()
            if isAvailable {
                try await backend.initialize()
                print("✅ Initialized backend: \(backend.name)")
            } else {
                print("⚠️ Backend not available: \(backend.name)")
            }
        } catch {
            print("❌ Failed to initialize backend \(backend.name): \(error)")
        }
    }
    
    /// Initialize all registered backends
    func initializeAllBackends() async {
        isInitializing = true
        defer { isInitializing = false }
        
        // Initialize backends sequentially to avoid actor isolation issues
        for backend in availableBackends {
            await initializeBackend(backend)
        }
        
        // If no active backend is set, try to set a default
        if activeBackend == nil {
            await setDefaultBackend()
        }
    }
    
    /// Set a default backend (prefer Apple Foundation if available)
    private func setDefaultBackend() async {
        // Try Apple Foundation first
        if let appleBackend = availableBackends.first(where: { $0.id == "apple-foundation" && $0.isAvailable }) {
            try? await setActiveBackend(appleBackend.id)
            return
        }
        
        // Fall back to first available backend
        if let firstAvailable = availableBackends.first(where: { $0.isAvailable }) {
            try? await setActiveBackend(firstAvailable.id)
        }
    }
    
    // MARK: - Persistence
    
    private func loadSavedActiveBackend() {
        guard let savedBackendId = userDefaults.string(forKey: activeBackendKey) else {
            return
        }
        
        // Will be set after backends are registered and initialized
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for registration
            if let backend = backendRegistry[savedBackendId], backend.isAvailable {
                try? await setActiveBackend(savedBackendId)
            }
        }
    }
    
    // MARK: - Cleanup
    
    /// Cleanup all backends
    func cleanupAllBackends() async {
        // Cleanup backends sequentially to avoid actor isolation issues
        for backend in availableBackends {
            await backend.cleanup()
        }
    }
}

// MARK: - Backend Info

extension BackendManager {
    /// Get information about all backends
    func getBackendInfo() -> [(backend: AIBackend, modelCount: Int?, status: BackendStatus)] {
        return availableBackends.map { backend in
            let status: BackendStatus = backend.isAvailable ? .available : .unavailable
            return (backend: backend, modelCount: nil, status: status)
        }
    }
}

enum BackendStatus {
    case available
    case unavailable
    case initializing
    case error(String)
    
    var displayText: String {
        switch self {
        case .available:
            return "Available"
        case .unavailable:
            return "Unavailable"
        case .initializing:
            return "Initializing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .available:
            return .green
        case .unavailable:
            return .gray
        case .initializing:
            return .orange
        case .error:
            return .red
        }
    }
}
