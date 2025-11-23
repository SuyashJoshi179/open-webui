//
//  OllamaService.swift
//  OpenWebUI
//
//  Ollama integration service
//

import Foundation

class OllamaService {
    static let shared = OllamaService()
    
    private let apiClient = APIClient.shared
    
    private init() {}
    
    // MARK: - Generate
    
    func generate(
        model: String,
        prompt: String,
        system: String? = nil,
        template: String? = nil,
        context: [Int]? = nil,
        options: GenerateOptions? = nil
    ) async throws -> GenerateResponse {
        let request = GenerateRequest(
            model: model,
            prompt: prompt,
            system: system,
            template: template,
            context: context,
            options: options,
            stream: false
        )
        
        return try await apiClient.request(
            path: "/ollama/api/generate",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Stream Generate
    
    func streamGenerate(
        model: String,
        prompt: String,
        system: String? = nil,
        options: GenerateOptions? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let request = GenerateRequest(
            model: model,
            prompt: prompt,
            system: system,
            template: nil,
            context: nil,
            options: options,
            stream: true
        )
        
        return apiClient.stream(
            path: "/ollama/api/generate",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Chat
    
    func chat(
        model: String,
        messages: [OllamaChatMessage],
        tools: [Tool]? = nil,
        options: GenerateOptions? = nil
    ) async throws -> ChatResponse {
        let request = ChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            stream: false,
            options: options
        )
        
        return try await apiClient.request(
            path: "/ollama/api/chat",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Stream Chat
    
    func streamChat(
        model: String,
        messages: [OllamaChatMessage],
        tools: [Tool]? = nil,
        options: GenerateOptions? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let request = ChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            stream: true,
            options: options
        )
        
        return apiClient.stream(
            path: "/ollama/api/chat",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - List Models
    
    func listModels() async throws -> [OllamaModel] {
        let response: ListModelsResponse = try await apiClient.request(
            path: "/ollama/api/tags"
        )
        return response.models
    }
    
    // MARK: - Pull Model
    
    func pullModel(name: String) -> AsyncThrowingStream<PullProgress, Error> {
        let request = PullRequest(name: name, stream: true)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in apiClient.stream(
                        path: "/ollama/api/pull",
                        method: "POST",
                        body: request
                    ) {
                        if let data = line.data(using: .utf8),
                           let progress = try? JSONDecoder().decode(PullProgress.self, from: data) {
                            continuation.yield(progress)
                            if progress.status == "success" {
                                continuation.finish()
                                return
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
    
    // MARK: - Delete Model
    
    func deleteModel(name: String) async throws {
        let request = DeleteRequest(name: name)
        let _: EmptyResponse = try await apiClient.request(
            path: "/ollama/api/delete",
            method: "DELETE",
            body: request
        )
    }
}

// MARK: - Ollama Models

struct GenerateRequest: Codable {
    let model: String
    let prompt: String
    let system: String?
    let template: String?
    let context: [Int]?
    let options: GenerateOptions?
    let stream: Bool
}

struct GenerateOptions: Codable {
    let temperature: Double?
    let topK: Int?
    let topP: Double?
    let numPredict: Int?
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case topK = "top_k"
        case topP = "top_p"
        case numPredict = "num_predict"
    }
}

struct GenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
    let context: [Int]?
    let totalDuration: Int64?
    let loadDuration: Int64?
    let promptEvalDuration: Int64?
    let evalDuration: Int64?
    
    enum CodingKeys: String, CodingKey {
        case model
        case response
        case done
        case context
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalDuration = "prompt_eval_duration"
        case evalDuration = "eval_duration"
    }
}

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let tools: [Tool]?
    let stream: Bool
    let options: GenerateOptions?
}

struct ChatResponse: Codable {
    let model: String
    let message: OllamaChatMessage
    let done: Bool
    let totalDuration: Int64?
    
    enum CodingKeys: String, CodingKey {
        case model
        case message
        case done
        case totalDuration = "total_duration"
    }
}

struct OllamaModel: Codable, Identifiable {
    let name: String
    let modifiedAt: Date
    let size: Int64
    let digest: String
    let details: ModelDetails?
    
    var id: String { name }
    
    struct ModelDetails: Codable {
        let format: String
        let family: String
        let parameterSize: String
        let quantizationLevel: String
        
        enum CodingKeys: String, CodingKey {
            case format
            case family
            case parameterSize = "parameter_size"
            case quantizationLevel = "quantization_level"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
        case digest
        case details
    }
}

struct ListModelsResponse: Codable {
    let models: [OllamaModel]
}

struct PullRequest: Codable {
    let name: String
    let stream: Bool
}

struct PullProgress: Codable {
    let status: String
    let digest: String?
    let total: Int64?
    let completed: Int64?
}

struct DeleteRequest: Codable {
    let name: String
}

struct EmptyResponse: Codable {}
