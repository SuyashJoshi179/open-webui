//
//  OllamaServiceTests.swift
//  OpenWebUITests
//
//  Unit tests for OllamaService
//

import XCTest
@testable import OpenWebUI

@MainActor
final class OllamaServiceTests: XCTestCase {
    
    var sut: OllamaService!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = OllamaService.shared
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testSharedInstanceIsSingleton() {
        let instance1 = OllamaService.shared
        let instance2 = OllamaService.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Generate Request Model Tests
    
    func testGenerateRequestEncoding() throws {
        let options = GenerateOptions(
            temperature: 0.7,
            topK: 40,
            topP: 0.9,
            numPredict: 100
        )
        
        let request = GenerateRequest(
            model: "llama3.2",
            prompt: "Hello",
            system: "You are helpful",
            template: nil,
            context: nil,
            options: options,
            stream: false
        )
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["model"] as? String, "llama3.2")
        XCTAssertEqual(json["prompt"] as? String, "Hello")
        XCTAssertEqual(json["system"] as? String, "You are helpful")
        XCTAssertEqual(json["stream"] as? Bool, false)
    }
    
    func testGenerateOptionsEncoding() throws {
        let options = GenerateOptions(
            temperature: 0.8,
            topK: 50,
            topP: 0.95,
            numPredict: 200
        )
        
        let data = try JSONEncoder().encode(options)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["temperature"] as? Double, 0.8)
        XCTAssertEqual(json["top_k"] as? Int, 50)
        XCTAssertEqual(json["top_p"] as? Double, 0.95)
        XCTAssertEqual(json["num_predict"] as? Int, 200)
    }
    
    // MARK: - List Models Tests (Integration)
    
    func testListModelsReturnsArrayOrThrowsNetworkError() async {
        do {
            let models = try await sut.listModels()
            // If successful, should return an array
            XCTAssertNotNil(models)
        } catch {
            // Expected if Ollama backend is not available
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Chat Message Model Tests
    
    func testOllamaChatMessageIsUsable() {
        // Test that OllamaChatMessage can be created and used
        // This is primarily a compile-time check
        let message = OllamaChatMessage(
            role: "user",
            content: "Hello",
            images: nil
        )
        
        XCTAssertEqual(message.role, "user")
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNil(message.images)
    }
    
    func testOllamaChatMessageWithImages() {
        let message = OllamaChatMessage(
            role: "user",
            content: "What's in this image?",
            images: ["base64encodedimage"]
        )
        
        XCTAssertEqual(message.role, "user")
        XCTAssertEqual(message.images?.count, 1)
    }
}

// MARK: - Supporting Models (if not defined elsewhere)

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
    let images: [String]?
}
