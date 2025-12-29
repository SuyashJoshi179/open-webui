//
//  LiteRTBackend.swift
//  OpenWebUI
//
//  Backend implementation for Google LiteRT (TensorFlow Lite) inference
//

import Foundation
import SwiftUI

/// Backend for running TensorFlow Lite models on-device
class LiteRTBackend: AIBackend {
    
    // MARK: - AIBackend Protocol
    
    let id = "litert"
    let name = "LiteRT"
    let description = "Run TensorFlow Lite models on-device. Optimized for mobile inference."
    let iconName = "cube.fill"
    
    var isAvailable: Bool {
        return isInitialized && currentModel != nil
    }
    
    var settings: AIBackendSettings {
        return liteRTSettings
    }
    
    // MARK: - Private Properties
    
    private var isInitialized = false
    private var currentModel: LiteRTModel?
    private var liteRTSettings = LiteRTSettings()
    
    // In production, this would interface with TensorFlow Lite library
    
    // MARK: - Initialization
    
    func initialize() async throws {
        // Load settings
        if let savedSettings = BackendSettingsManager.shared.loadSettings(
            for: id,
            type: LiteRTSettings.self
        ) {
            liteRTSettings = savedSettings
        }
        
        // Validate settings
        switch liteRTSettings.validate() {
        case .success:
            break
        case .failure(let error):
            throw BackendError.invalidConfiguration(error.localizedDescription)
        }
        
        // Load model if path is specified
        if let modelPath = liteRTSettings.modelPath, !modelPath.isEmpty {
            try await loadModel(path: modelPath)
        }
        
        isInitialized = true
    }
    
    func checkAvailability() async -> Bool {
        // LiteRT is available on all iOS devices
        return true
    }
    
    // MARK: - Model Management
    
    func listModels() async throws -> [AIModel] {
        var models: [AIModel] = []
        
        // List TFLite models from the models directory
        let modelsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("tflite-models")
        
        if FileManager.default.fileExists(atPath: modelsDir.path) {
            let files = try FileManager.default.contentsOfDirectory(
                at: modelsDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            for file in files where file.pathExtension == "tflite" {
                let resources = try file.resourceValues(forKeys: [.fileSizeKey])
                
                models.append(AIModel(
                    id: "litert-\(file.lastPathComponent)",
                    name: file.deletingPathExtension().lastPathComponent,
                    backendId: id,
                    description: "TensorFlow Lite model",
                    capabilities: ModelCapabilities(
                        supportsStreaming: true,
                        supportsVision: false,
                        supportsFunctionCalling: false,
                        maxContextLength: 2048,
                        maxOutputTokens: 1024
                    ),
                    metadata: ModelMetadata(
                        size: Int64(resources.fileSize ?? 0)
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
                    // In production, this would call the actual TFLite inference
                    // For now, simulate streaming response
                    let response = "This is a simulated response from LiteRT backend. " +
                                   "In production, this would use TensorFlow Lite " +
                                   "to run optimized on-device inference."
                    
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
        // In production, this would load the actual TFLite model
        currentModel = LiteRTModel(
            path: path,
            threads: liteRTSettings.numThreads,
            useGPU: liteRTSettings.useGPUDelegate,
            useNNAPI: liteRTSettings.useNNAPI
        )
    }
}

// MARK: - Supporting Types

struct LiteRTModel {
    let path: String
    let threads: Int
    let useGPU: Bool
    let useNNAPI: Bool
}

// MARK: - Settings

struct LiteRTSettings: AIBackendSettings, Equatable {
    var backendId: String = "litert"
    var modelPath: String?
    var numThreads: Int = 4
    var useGPUDelegate: Bool = true
    var useNNAPI: Bool = false
    var useXNNPack: Bool = true
    
    func settingsView() -> AnyView {
        AnyView(LiteRTSettingsView(settings: self))
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
        
        if numThreads < 1 || numThreads > 8 {
            return .failure(.invalidValue(
                field: "numThreads",
                reason: "Must be between 1 and 8"
            ))
        }
        
        return .success(())
    }
    
    mutating func resetToDefaults() {
        modelPath = nil
        numThreads = 4
        useGPUDelegate = true
        useNNAPI = false
        useXNNPack = true
    }
}

// MARK: - Settings View

struct LiteRTSettingsView: View {
    @State private var settings: LiteRTSettings
    @State private var showModelPicker = false
    
    init(settings: LiteRTSettings) {
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
            } footer: {
                Text("Select a .tflite model file")
            }
            
            Section {
                Stepper("CPU Threads: \(settings.numThreads)",
                       value: $settings.numThreads,
                       in: 1...8)
            } header: {
                Text("CPU Settings")
            }
            
            Section {
                Toggle("Use GPU Delegate", isOn: $settings.useGPUDelegate)
                Toggle("Use NNAPI", isOn: $settings.useNNAPI)
                Toggle("Use XNNPack", isOn: $settings.useXNNPack)
            } header: {
                Text("Hardware Acceleration")
            } footer: {
                Text("GPU Delegate provides best performance on most devices")
            }
            
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("LiteRT Settings")
        .sheet(isPresented: $showModelPicker) {
            // Model file picker would go here
            Text("Model Picker")
        }
        .onChange(of: settings) { _, newSettings in
            try? BackendSettingsManager.shared.saveSettings(newSettings)
        }
    }
}
