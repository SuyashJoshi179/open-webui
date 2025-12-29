//
//  OpenAICompatibleBackend.swift
//  OpenWebUI
//
//  OpenAI-compatible API backend for external AI services
//

import Foundation
import SwiftUI

@MainActor
class OpenAICompatibleBackend: AIBackend, ObservableObject {
    // MARK: - AIBackend Protocol Properties
    
    let id = "openai-compatible"
    let name = "OpenAI Compatible"
    let description = "Connect to OpenAI, Ollama, or any OpenAI-compatible API endpoint"
    let iconName = "cloud.fill"
    
    @Published var isAvailable: Bool = false
    var settings: AIBackendSettings {
        get { _settings }
        set { _settings = newValue as! OpenAICompatibleSettings }
    }
    
    // MARK: - Private Properties
    
    private var _settings: OpenAICompatibleSettings
    private let apiClient = APIClient.shared
    
    // MARK: - Initialization
    
    init() {
        // Load settings from persistence
        if let savedSettings = BackendSettingsManager.shared.loadSettings(for: "openai-compatible", type: OpenAICompatibleSettings.self) {
            self._settings = savedSettings
        } else {
            self._settings = OpenAICompatibleSettings()
        }
        
        // Check availability on init
        checkAvailabilitySync()
    }
    
    // MARK: - AIBackend Protocol Methods
    
    func initialize() async throws {
        let available = await checkAvailability()
        
        if !available {
            throw BackendError.notAvailable
        }
    }
    
    func checkAvailability() async -> Bool {
        // Check if API URL is configured
        let hasConfig = !_settings.apiURL.isEmpty
        
        if hasConfig {
            // Try to ping the API
            do {
                _ = try await listModels()
                self.isAvailable = true
                print("✅ OpenAI-compatible API is available")
                return true
            } catch {
                self.isAvailable = false
                print("⚠️ OpenAI-compatible API configured but unreachable: \(error)")
                return false
            }
        } else {
            self.isAvailable = false
            print("ℹ️ OpenAI-compatible API not configured")
            return false
        }
    }
    
    func listModels() async throws -> [AIModel] {
        guard !_settings.apiURL.isEmpty else {
            return []
        }
        
        // Construct URL
        guard var urlComponents = URLComponents(string: _settings.apiURL) else {
            throw BackendError.invalidConfiguration("Invalid API URL")
        }
        
        // Ensure path ends with /models
        if !urlComponents.path.hasSuffix("/models") {
            urlComponents.path = urlComponents.path.trimmingCharacters(in: ["/"])
            urlComponents.path += "/models"
        }
        
        guard let url = urlComponents.url else {
            throw BackendError.invalidConfiguration("Could not construct models URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if !_settings.apiKey.isEmpty {
            request.setValue("Bearer \(_settings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let orgId = _settings.organizationId, !orgId.isEmpty {
            request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw BackendError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder.api
        let modelsResponse = try decoder.decode(OpenAIModelsResponse.self, from: data)
        
        return modelsResponse.data.map { model in
            AIModel(
                id: model.id,
                name: model.id,
                backendId: id,
                description: "OpenAI-compatible model",
                capabilities: ModelCapabilities(
                    supportsStreaming: true,
                    supportsVision: false,
                    supportsFunctionCalling: false,
                    maxContextLength: model.contextWindow ?? 4096,
                    maxOutputTokens: 2048
                ),
                metadata: ModelMetadata(
                    size: nil,
                    family: model.ownedBy
                )
            )
        }
    }
    
    func streamGenerate(
        model: String,
        prompt: String,
        context: AIContext,
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard !_settings.apiURL.isEmpty else {
                    continuation.finish(throwing: BackendError.notAvailable)
                    return
                }
                
                // Build messages array
                var messages: [OpenAIChatCompletionRequest.ChatMessage] = []
                
                // Add system prompt if provided
                if let systemPrompt = context.systemPrompt {
                    messages.append(OpenAIChatCompletionRequest.ChatMessage(
                        role: "system",
                        content: systemPrompt
                    ))
                }
                
                // Add conversation history
                for historyMsg in context.conversationHistory {
                    messages.append(OpenAIChatCompletionRequest.ChatMessage(
                        role: historyMsg.role,
                        content: historyMsg.content
                    ))
                }
                
                // Add current prompt
                messages.append(OpenAIChatCompletionRequest.ChatMessage(
                    role: "user",
                    content: prompt
                ))
                
                // Create request
                let request = OpenAIChatCompletionRequest(
                    model: model,
                    messages: messages,
                    temperature: parameters.temperature,
                    maxTokens: parameters.maxTokens,
                    topP: parameters.topP,
                    frequencyPenalty: parameters.frequencyPenalty,
                    presencePenalty: parameters.presencePenalty,
                    stream: true,
                    tools: nil
                )
                
                do {
                    let stream = try await streamChatCompletion(request: request)
                    
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: BackendError.generationFailed(error.localizedDescription))
                }
            }
        }
    }
    
    func cleanup() async {
        // No cleanup needed for API-based backend
    }
    
    // MARK: - Private Methods
    
    private func checkAvailabilitySync() {
        self.isAvailable = !_settings.apiURL.isEmpty
    }
    
    private func streamChatCompletion(
        request: OpenAIChatCompletionRequest
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard var urlComponents = URLComponents(string: _settings.apiURL) else {
            throw BackendError.invalidConfiguration("Invalid API URL")
        }
        
        // Ensure path for chat completions
        if !urlComponents.path.contains("chat/completions") {
            urlComponents.path = urlComponents.path.trimmingCharacters(in: ["/"])
            if urlComponents.path.hasSuffix("/v1") {
                urlComponents.path += "/chat/completions"
            } else {
                urlComponents.path += "/v1/chat/completions"
            }
        }
        
        guard let url = urlComponents.url else {
            throw BackendError.invalidConfiguration("Could not construct chat completions URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !_settings.apiKey.isEmpty {
            urlRequest.setValue("Bearer \(_settings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let orgId = _settings.organizationId, !orgId.isEmpty {
            urlRequest.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: BackendError.networkError("Invalid response"))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: BackendError.networkError("HTTP \(httpResponse.statusCode)"))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        // Skip empty lines and heartbeats
                        guard !line.isEmpty, line != ": ping" else {
                            continue
                        }
                        
                        // SSE format: "data: {json}"
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            // Check for stream end
                            if jsonString == "[DONE]" {
                                break
                            }
                            
                            // Parse JSON chunk
                            guard let jsonData = jsonString.data(using: .utf8) else {
                                continue
                            }
                            
                            let decoder = JSONDecoder()
                            decoder.keyDecodingStrategy = .convertFromSnakeCase
                            
                            if let chunk = try? decoder.decode(ChatCompletionChunk.self, from: jsonData) {
                                if let content = chunk.choices.first?.delta.content {
                                    continuation.yield(content)
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - OpenAICompatibleSettings

struct OpenAICompatibleSettings: AIBackendSettings {
    var backendId: String = "openai-compatible"
    
    var apiURL: String = ""
    var apiKey: String = ""
    var organizationId: String? = nil
    var defaultModel: String = "gpt-4"
    var timeout: TimeInterval = 60.0
    
    func settingsView() -> AnyView {
        AnyView(OpenAICompatibleSettingsView(settings: self))
    }
    
    func validate() -> Result<Void, SettingsError> {
        // Validate API URL
        if apiURL.isEmpty {
            return .failure(.missingRequiredField("API URL"))
        }
        
        guard let _ = URL(string: apiURL) else {
            return .failure(.invalidValue(field: "API URL", reason: "Not a valid URL"))
        }
        
        // Validate timeout
        if timeout < 1 || timeout > 300 {
            return .failure(.invalidValue(field: "timeout", reason: "Must be between 1 and 300 seconds"))
        }
        
        return .success(())
    }
    
    mutating func resetToDefaults() {
        apiURL = ""
        apiKey = ""
        organizationId = nil
        defaultModel = "gpt-4"
        timeout = 60.0
    }
}

// MARK: - OpenAICompatibleSettingsView

struct OpenAICompatibleSettingsView: View {
    @State var settings: OpenAICompatibleSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showingAPIKey = false
    @State private var testingConnection = false
    @State private var testResult: String?
    
    var body: some View {
        Form {
            Section {
                TextField("API URL", text: $settings.apiURL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                HStack {
                    if showingAPIKey {
                        TextField("API Key", text: $settings.apiKey)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("API Key", text: $settings.apiKey)
                    }
                    
                    Button(action: { showingAPIKey.toggle() }) {
                        Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                
                TextField("Organization ID (Optional)", text: Binding(
                    get: { settings.organizationId ?? "" },
                    set: { settings.organizationId = $0.isEmpty ? nil : $0 }
                ))
                .autocapitalization(.none)
                .autocorrectionDisabled()
            } header: {
                Label("API Configuration", systemImage: "network")
            } footer: {
                Text("Enter your OpenAI-compatible API endpoint. Examples: OpenAI, Ollama, LocalAI, etc.")
            }
            
            Section {
                TextField("Default Model", text: $settings.defaultModel)
                    .autocapitalization(.none)
                
                HStack {
                    Text("Timeout")
                    Spacer()
                    Text("\(Int(settings.timeout))s")
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $settings.timeout, in: 10...300, step: 10)
            } header: {
                Label("Request Settings", systemImage: "slider.horizontal.3")
            }
            
            Section {
                Button(action: testConnection) {
                    HStack {
                        if testingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(testingConnection ? "Testing..." : "Test Connection")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(settings.apiURL.isEmpty || testingConnection)
                
                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("✅") ? .green : .red)
                }
            } header: {
                Label("Connection Test", systemImage: "checkmark.circle")
            }
            
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                    testResult = nil
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
        .navigationTitle("OpenAI Compatible Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func testConnection() {
        testingConnection = true
        testResult = nil
        
        Task {
            do {
                let backend = OpenAICompatibleBackend()
                backend.settings = settings
                
                let models = try await backend.listModels()
                
                await MainActor.run {
                    testResult = "✅ Connected! Found \(models.count) model(s)"
                    testingConnection = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Connection failed: \(error.localizedDescription)"
                    testingConnection = false
                }
            }
        }
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

// MARK: - API Models
// Note: ModelsResponse and ChatCompletionRequest are defined in APIModels.swift
// We define backend-specific models here only

struct OpenAIModelsResponse: Codable {
    let data: [ModelInfo]
    let object: String?
    
    struct ModelInfo: Codable {
        let id: String
        let object: String?
        let created: Int?
        let ownedBy: String?
        let contextWindow: Int?
        
        enum CodingKeys: String, CodingKey {
            case id
            case object
            case created
            case ownedBy = "owned_by"
            case contextWindow = "context_window"
        }
    }
}

struct OpenAIChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let frequencyPenalty: Double?
    let presencePenalty: Double?
    let stream: Bool
    let tools: [AITool]?
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
}

struct ChatCompletionChunk: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        struct Delta: Codable {
            let role: String?
            let content: String?
        }
    }
}

struct AITool: Codable {
    let type: String
    let function: FunctionDefinition
    
    struct FunctionDefinition: Codable {
        let name: String
        let description: String?
        let parameters: [String: AnyCodable]?
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// Note: JSONDecoder.api extension already exists in APIClient.swift
