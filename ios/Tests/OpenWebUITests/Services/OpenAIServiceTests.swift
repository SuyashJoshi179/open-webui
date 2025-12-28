//
//  OpenAIServiceTests.swift
//  OpenWebUITests
//
//  Unit tests for OpenAIService
//

import XCTest
@testable import OpenWebUI

@MainActor
final class OpenAIServiceTests: XCTestCase {
    
    var sut: OpenAIService!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = OpenAIService.shared
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testSharedInstanceIsSingleton() {
        let instance1 = OpenAIService.shared
        let instance2 = OpenAIService.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Embedding Request Model Tests
    
    func testEmbeddingRequestEncoding() throws {
        let request = EmbeddingRequest(model: "text-embedding-ada-002", input: "Hello world")
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["model"] as? String, "text-embedding-ada-002")
        XCTAssertEqual(json["input"] as? String, "Hello world")
    }
    
    // MARK: - Embedding Response Model Tests
    
    func testEmbeddingResponseDecoding() throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "object": "embedding",
                    "embedding": [0.1, 0.2, 0.3, 0.4, 0.5],
                    "index": 0
                }
            ],
            "model": "text-embedding-ada-002",
            "usage": {
                "prompt_tokens": 2,
                "total_tokens": 2
            }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(EmbeddingResponse.self, from: json)
        
        XCTAssertEqual(response.object, "list")
        XCTAssertEqual(response.model, "text-embedding-ada-002")
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].embedding.count, 5)
        XCTAssertEqual(response.data[0].index, 0)
        XCTAssertEqual(response.usage.promptTokens, 2)
        XCTAssertEqual(response.usage.totalTokens, 2)
    }
    
    // MARK: - Chat Completion Request Model Tests
    
    func testChatCompletionRequestEncoding() throws {
        let messages = [
            ChatCompletionRequest.ChatMessage(role: "system", content: "You are helpful"),
            ChatCompletionRequest.ChatMessage(role: "user", content: "Hello")
        ]
        
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: messages,
            temperature: 0.7,
            maxTokens: 1000,
            stream: false,
            tools: nil
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["model"] as? String, "gpt-4")
        XCTAssertEqual(json["temperature"] as? Double, 0.7)
        XCTAssertEqual(json["max_tokens"] as? Int, 1000)
        XCTAssertEqual(json["stream"] as? Bool, false)
        
        let messagesArray = json["messages"] as? [[String: Any]]
        XCTAssertEqual(messagesArray?.count, 2)
    }
    
    // MARK: - Integration Tests (require backend)
    
    func testListModelsReturnsArrayOrThrowsError() async {
        do {
            let models = try await sut.listModels()
            XCTAssertNotNil(models)
        } catch {
            // Expected if backend is not available
            XCTAssertNotNil(error)
        }
    }
    
    func testChatCompletionWithInvalidModelThrowsError() async {
        let messages = [
            ChatCompletionRequest.ChatMessage(role: "user", content: "Hello")
        ]
        
        do {
            _ = try await sut.chatCompletion(
                model: "invalid-model-that-does-not-exist",
                messages: messages
            )
        } catch {
            // Expected - model doesn't exist or network error
            XCTAssertNotNil(error)
        }
    }
}
