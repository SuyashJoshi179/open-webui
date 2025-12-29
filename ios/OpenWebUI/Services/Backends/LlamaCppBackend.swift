//
//  LlamaCppBackend.swift
//  OpenWebUI
//
//  Backend implementation for Llama.cpp local inference
//

import Foundation
import SwiftUI

/// Backend for running quantized LLMs locally using llama.cpp
class LlamaCppBackend: AIBackend {
    
    // MARK: - AIBackend Protocol
    
    let id = "llama-cpp"
    let name = "Llama.cpp"
    let description = "Run quantized LLMs locally using llama.cpp. Supports GGUF format models."
    let iconName = "cpu.fill"
    
    var isAvailable: Bool {
        return isInitialized && currentModel != nil
    }
    
    var settings: AIBackendSettings {
        return llamaSettings
    }
    
    // MARK: - Private Properties
    
    private var isInitialized = false
    private var currentModel: LlamaCppModel?
    private var llamaSettings = LlamaCppSettings()
    
    // In production, this would wrap the actual llama.cpp C++ library
    // For now, it's a placeholder structure
    
    // MARK: - Initialization
    
    func initialize() async throws {
        // Load settings
        if let savedSettings = BackendSettingsManager.shared.loadSettings(
            for: id,
            type: LlamaCppSettings.self
        ) {
            llamaSettings = savedSettings
        }
        
        // Validate settings
        switch llamaSettings.validate() {
        case .success:
            break
        case .failure(let error):
            throw BackendError.invalidConfiguration(error.localizedDescription)
        }
        
        // Load model if path is specified
        if let modelPath = llamaSettings.modelPath, !modelPath.isEmpty {
            try await loadModel(path: modelPath)
        }
        
        isInitialized = true
    }
    
    func checkAvailability() async -> Bool {
        // Llama.cpp is available on all iOS devices
        // But requires a model file to be useful
        return true
    }
    
    // MARK: - Model Management
    
    func listModels() async throws -> [AIModel] {
        var models: [AIModel] = []
        
        // List downloaded GGUF models from the models directory
        let modelsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("llama-models")
        
        if FileManager.default.fileExists(atPath: modelsDir.path) {
            let files = try FileManager.default.contentsOfDirectory(
                at: modelsDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            for file in files where file.pathExtension == "gguf" {
                let resources = try file.resourceValues(forKeys: [.fileSizeKey])
                
                models.append(AIModel(
                    id: "llama-cpp-\(file.lastPathComponent)",
                    name: file.deletingPathExtension().lastPathComponent,
                    backendId: id,
                    description: "GGUF quantized model",
                    capabilities: ModelCapabilities(
                        supportsStreaming: true,
                        supportsVision: false,
                        supportsFunctionCalling: false,
                        maxContextLength: llamaSettings.contextSize,
                        maxOutputTokens: 2048
                    ),
                    metadata: ModelMetadata(
                        size: Int64(resources.fileSize ?? 0),
                        quantization: detectQuantization(from: file.lastPathComponent)
                    )
                ))
            }
        }
        
        return models
    }
    
    // MARK: - Generation
    
    func streamGenerate(
        model: String,
        prompt: String,
        context: AIContext,
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard isInitialized else {
                    continuation.finish(throwing: BackendError.notInitialized)
                    return
                }
                
                guard let currentModel = currentModel else {
                    continuation.finish(throwing: BackendError.modelNotFound(model))
                    return
                }
                
                do {
                    // In production, this would call the actual llama.cpp inference
                    // For now, simulate streaming response
                    let response = "This is a simulated response from Llama.cpp backend. " +
                                   "In production, this would use the actual llama.cpp library " +
                                   "to generate text using the loaded GGUF model."
                    
                    for word in response.split(separator: " ") {
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                        continuation.yield(String(word) + " ")
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: BackendError.generationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        currentModel = nil
        isInitialized = false
    }
    
    // MARK: - Private Methods
    
    private func loadModel(path: String) async throws {
        // In production, this would load the actual GGUF model
        currentModel = LlamaCppModel(
            path: path,
            contextSize: llamaSettings.contextSize,
            threads: llamaSettings.threads,
            gpuLayers: llamaSettings.gpuLayers
        )
    }
    
    private func detectQuantization(from filename: String) -> String {
        let quantTypes = ["Q4_0", "Q4_1", "Q5_0", "Q5_1", "Q8_0", "Q8_1", "F16", "F32"]
        for quant in quantTypes {
            if filename.contains(quant) {
                return quant
            }
        }
        return "Unknown"
    }
}

// MARK: - Supporting Types

struct LlamaCppModel {
    let path: String
    let contextSize: Int
    let threads: Int
    let gpuLayers: Int
}

// MARK: - Settings

struct LlamaCppSettings: AIBackendSettings, Equatable {
    var backendId: String = "llama-cpp"
    var modelPath: String?
    var contextSize: Int = 2048
    var threads: Int = 4
    var gpuLayers: Int = 0
    var useMmap: Bool = true
    var useMlock: Bool = false
    
    func settingsView() -> AnyView {
        AnyView(LlamaCppSettingsView(settings: self))
    }
    
    func validate() -> Result<Void, SettingsError> {
        if let path = modelPath, !path.isEmpty {
            if !FileManager.default.fileExists(atPath: path) {
                return .failure(.invalidValue(
                    field: "modelPath",
                    reason: "File does not exist"
                ))
            }
        }
        
        if contextSize < 128 || contextSize > 32768 {
            return .failure(.invalidValue(
                field: "contextSize",
                reason: "Must be between 128 and 32768"
            ))
        }
        
        if threads < 1 || threads > 16 {
            return .failure(.invalidValue(
                field: "threads",
                reason: "Must be between 1 and 16"
            ))
        }
        
        return .success(())
    }
    
    mutating func resetToDefaults() {
        modelPath = nil
        contextSize = 2048
        threads = 4
        gpuLayers = 0
        useMmap = true
        useMlock = false
    }
}

// MARK: - Settings View

struct LlamaCppSettingsView: View {
    @State private var settings: LlamaCppSettings
    @State private var showModelPicker = false
    
    init(settings: LlamaCppSettings) {
        _settings = State(initialValue: settings)
    }
    
    var body: some View {
        Form {
            Section {
                Button(action: { showModelPicker = true }) {
                    HStack {
                        Text("Model File")
                        Spacer()
                        if let path = settings.modelPath {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Model")
            }
            
            Section {
                Stepper("Context Size: \(settings.contextSize)", 
                       value: $settings.contextSize,
                       in: 128...32768,
                       step: 128)
                
                Stepper("Threads: \(settings.threads)",
                       value: $settings.threads,
                       in: 1...16)
                
                Stepper("GPU Layers: \(settings.gpuLayers)",
                       value: $settings.gpuLayers,
                       in: 0...100)
            } header: {
                Text("Performance")
            } footer: {
                Text("More GPU layers = faster but uses more memory")
            }
            
            Section {
                Toggle("Use Memory Mapping (mmap)", isOn: $settings.useMmap)
                Toggle("Use Memory Locking (mlock)", isOn: $settings.useMlock)
            } header: {
                Text("Memory Options")
            }
            
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Llama.cpp Settings")
        .sheet(isPresented: $showModelPicker) {
            // Model file picker would go here
            Text("Model Picker")
        }
        .onChange(of: settings) { _, newSettings in
            try? BackendSettingsManager.shared.saveSettings(newSettings)
        }
    }
}
