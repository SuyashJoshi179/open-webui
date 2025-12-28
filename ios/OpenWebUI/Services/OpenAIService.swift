//
//  OpenAIService.swift
//  OpenWebUI
//
//  OpenAI API integration service
//

import Foundation
import Combine
import SwiftUI

@MainActor
class OpenAIService {
    static let shared = OpenAIService()
    
    private let apiClient = APIClient.shared
    @AppStorage("externalAPIURL") private var externalAPIURL = ""
    @AppStorage("externalAPIKey") private var externalAPIKey = ""
    
    private init() {}
    
    // MARK: - Chat Completion
    
    func chatCompletion(
        model: String,
        messages: [ChatCompletionRequest.ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        tools: [Tool]? = nil
    ) async throws -> ChatCompletionResponse {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: false,
            tools: tools
        )
        
        return try await apiClient.request(
            path: "/openai/v1/chat/completions",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Streaming Chat Completion
    
    func streamChatCompletion(
        model: String,
        messages: [ChatCompletionRequest.ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        tools: [Tool]? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: true,
            tools: tools
        )
        
        return apiClient.stream(
            path: "/openai/v1/chat/completions",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - List Models
    
    func listModels() async throws -> [Model] {
        // Check if external API is configured
        guard !externalAPIURL.isEmpty else {
            return [] // No external API configured
        }
        
        // Use custom API client with external URL
        let url = URL(string: externalAPIURL)!.appendingPathComponent("/models")
        var request = URLRequest(url: url)
        
        if !externalAPIKey.isEmpty {
            request.setValue("Bearer \(externalAPIKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder.api.decode(ModelsResponse.self, from: data)
        return response.data
    }
    
    // MARK: - Embeddings
    
    func createEmbedding(
        model: String,
        input: String
    ) async throws -> EmbeddingResponse {
        let request = EmbeddingRequest(model: model, input: input)
        
        return try await apiClient.request(
            path: "/openai/v1/embeddings",
            method: "POST",
            body: request
        )
    }
}

// MARK: - Embedding Models

struct EmbeddingRequest: Codable {
    let model: String
    let input: String
}

struct EmbeddingResponse: Codable {
    let object: String
    let data: [EmbeddingData]
    let model: String
    let usage: Usage
    
    struct EmbeddingData: Codable {
        let object: String
        let embedding: [Float]
        let index: Int
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
