//
//  APIModelsTests.swift
//  OpenWebUITests
//
//  Unit tests for API models
//

import XCTest
@testable import OpenWebUI

final class APIModelsTests: XCTestCase {
    
    // MARK: - User Model Tests
    
    func testUserDecoding() throws {
        let json = """
        {
            "id": "user-123",
            "email": "test@example.com",
            "name": "Test User",
            "role": "user",
            "profile_image_url": "https://example.com/avatar.png",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let user = try decoder.decode(User.self, from: json)
        
        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.role, .user)
        XCTAssertEqual(user.profileImageUrl, "https://example.com/avatar.png")
    }
    
    func testUserRoleDecoding() throws {
        let testCases: [(String, User.UserRole)] = [
            ("\"admin\"", .admin),
            ("\"user\"", .user),
            ("\"pending\"", .pending)
        ]
        
        for (json, expectedRole) in testCases {
            let data = json.data(using: .utf8)!
            let role = try JSONDecoder().decode(User.UserRole.self, from: data)
            XCTAssertEqual(role, expectedRole)
        }
    }
    
    func testUserDecodingWithNullProfileImage() throws {
        let json = """
        {
            "id": "user-123",
            "email": "test@example.com",
            "name": "Test User",
            "role": "user",
            "profile_image_url": null,
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let user = try decoder.decode(User.self, from: json)
        
        XCTAssertNil(user.profileImageUrl)
    }
    
    // MARK: - Login Request Tests
    
    func testLoginRequestEncoding() throws {
        let request = LoginRequest(email: "test@example.com", password: "password123")
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["email"] as? String, "test@example.com")
        XCTAssertEqual(json["password"] as? String, "password123")
    }
    
    func testSignupRequestEncoding() throws {
        let request = SignupRequest(email: "test@example.com", password: "password123", name: "Test User")
        
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["email"] as? String, "test@example.com")
        XCTAssertEqual(json["password"] as? String, "password123")
        XCTAssertEqual(json["name"] as? String, "Test User")
    }
    
    // MARK: - Model Tests
    
    func testModelDecoding() throws {
        let json = """
        {
            "id": "gpt-4",
            "name": "GPT-4",
            "description": "OpenAI GPT-4 model",
            "provider": "openai",
            "owned_by": "openai",
            "capabilities": {
                "chat": true,
                "completion": true,
                "embedding": false,
                "vision": true,
                "function_calling": true
            },
            "info": {
                "context_length": 8192,
                "parameters": "1.8T",
                "quantization": null
            }
        }
        """.data(using: .utf8)!
        
        let model = try JSONDecoder().decode(Model.self, from: json)
        
        XCTAssertEqual(model.id, "gpt-4")
        XCTAssertEqual(model.name, "GPT-4")
        XCTAssertEqual(model.description, "OpenAI GPT-4 model")
        XCTAssertEqual(model.provider, .openai)
        XCTAssertEqual(model.owned_by, "openai")
        XCTAssertEqual(model.capabilities?.chat, true)
        XCTAssertEqual(model.capabilities?.vision, true)
        XCTAssertEqual(model.capabilities?.functionCalling, true)
        XCTAssertEqual(model.info?.contextLength, 8192)
    }
    
    func testModelProviderDecoding() throws {
        let testCases: [(String, Model.ModelProvider)] = [
            ("\"openai\"", .openai),
            ("\"ollama\"", .ollama),
            ("\"local\"", .local),
            ("\"custom\"", .custom)
        ]
        
        for (json, expectedProvider) in testCases {
            let data = json.data(using: .utf8)!
            let provider = try JSONDecoder().decode(Model.ModelProvider.self, from: data)
            XCTAssertEqual(provider, expectedProvider)
        }
    }
    
    // MARK: - Message Tests
    
    func testMessageDecoding() throws {
        let json = """
        {
            "id": "msg-123",
            "chat_id": "chat-456",
            "role": "assistant",
            "content": "Hello, how can I help you?",
            "model_id": "gpt-4",
            "timestamp": "2024-01-01T12:00:00Z",
            "metadata": {
                "tokens": 10,
                "finish_reason": "stop"
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(Message.self, from: json)
        
        XCTAssertEqual(message.id, "msg-123")
        XCTAssertEqual(message.chatId, "chat-456")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hello, how can I help you?")
        XCTAssertEqual(message.modelId, "gpt-4")
        XCTAssertEqual(message.metadata?.tokens, 10)
        XCTAssertEqual(message.metadata?.finishReason, "stop")
    }
    
    func testMessageRoleDecoding() throws {
        let testCases: [(String, Message.MessageRole)] = [
            ("\"system\"", .system),
            ("\"user\"", .user),
            ("\"assistant\"", .assistant),
            ("\"function\"", .function)
        ]
        
        for (json, expectedRole) in testCases {
            let data = json.data(using: .utf8)!
            let role = try JSONDecoder().decode(Message.MessageRole.self, from: data)
            XCTAssertEqual(role, expectedRole)
        }
    }
    
    // MARK: - Chat Completion Tests
    
    func testChatCompletionRequestEncoding() throws {
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                ChatCompletionRequest.ChatMessage(role: "user", content: "Hello")
            ],
            temperature: 0.7,
            maxTokens: 1000,
            stream: true,
            tools: nil
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["model"] as? String, "gpt-4")
        XCTAssertEqual(json["temperature"] as? Double, 0.7)
        XCTAssertEqual(json["max_tokens"] as? Int, 1000)
        XCTAssertEqual(json["stream"] as? Bool, true)
    }
    
    func testChatCompletionResponseDecoding() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1704067200,
            "model": "gpt-4",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello! How can I help you today?"
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 8,
                "total_tokens": 18
            }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: json)
        
        XCTAssertEqual(response.id, "chatcmpl-123")
        XCTAssertEqual(response.model, "gpt-4")
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices[0].message.content, "Hello! How can I help you today?")
        XCTAssertEqual(response.choices[0].finishReason, "stop")
        XCTAssertEqual(response.usage?.promptTokens, 10)
        XCTAssertEqual(response.usage?.completionTokens, 8)
        XCTAssertEqual(response.usage?.totalTokens, 18)
    }
    
    // MARK: - Tool Tests
    
    func testToolDecoding() throws {
        let json = """
        {
            "id": "tool-123",
            "name": "get_weather",
            "description": "Get the current weather for a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "The city and state"
                    },
                    "unit": {
                        "type": "string",
                        "description": "Temperature unit",
                        "enum": ["celsius", "fahrenheit"]
                    }
                },
                "required": ["location"]
            },
            "enabled": true
        }
        """.data(using: .utf8)!
        
        let tool = try JSONDecoder().decode(Tool.self, from: json)
        
        XCTAssertEqual(tool.id, "tool-123")
        XCTAssertEqual(tool.name, "get_weather")
        XCTAssertEqual(tool.enabled, true)
        XCTAssertEqual(tool.parameters.type, "object")
        XCTAssertEqual(tool.parameters.required, ["location"])
    }
    
    // MARK: - Document Tests
    
    func testDocumentDecoding() throws {
        let json = """
        {
            "id": "doc-123",
            "name": "example.pdf",
            "type": "application/pdf",
            "size": 1048576,
            "uploaded_at": "2024-01-01T00:00:00Z",
            "metadata": {
                "pages": 10,
                "chunks": 50,
                "indexed": true
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(Document.self, from: json)
        
        XCTAssertEqual(document.id, "doc-123")
        XCTAssertEqual(document.name, "example.pdf")
        XCTAssertEqual(document.type, "application/pdf")
        XCTAssertEqual(document.size, 1048576)
        XCTAssertEqual(document.metadata?.pages, 10)
        XCTAssertEqual(document.metadata?.chunks, 50)
        XCTAssertEqual(document.metadata?.indexed, true)
    }
    
    // MARK: - Knowledge Base Tests
    
    func testKnowledgeBaseDecoding() throws {
        let json = """
        {
            "id": "kb-123",
            "name": "My Knowledge Base",
            "description": "A collection of documents",
            "document_ids": ["doc-1", "doc-2", "doc-3"],
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let knowledgeBase = try decoder.decode(KnowledgeBase.self, from: json)
        
        XCTAssertEqual(knowledgeBase.id, "kb-123")
        XCTAssertEqual(knowledgeBase.name, "My Knowledge Base")
        XCTAssertEqual(knowledgeBase.description, "A collection of documents")
        XCTAssertEqual(knowledgeBase.documentIds, ["doc-1", "doc-2", "doc-3"])
    }
    
    // MARK: - API Error Tests
    
    func testAPIErrorDecoding() throws {
        let json = """
        {
            "code": "AUTH_FAILED",
            "message": "Invalid credentials",
            "details": {
                "field": "password"
            }
        }
        """.data(using: .utf8)!
        
        let error = try JSONDecoder().decode(APIError.self, from: json)
        
        XCTAssertEqual(error.code, "AUTH_FAILED")
        XCTAssertEqual(error.message, "Invalid credentials")
        XCTAssertEqual(error.details?["field"], "password")
        XCTAssertEqual(error.errorDescription, "Invalid credentials")
    }
}
