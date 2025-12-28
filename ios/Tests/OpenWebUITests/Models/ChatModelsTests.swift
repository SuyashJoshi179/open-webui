//
//  ChatModelsTests.swift
//  OpenWebUITests
//
//  Unit tests for Chat models
//

import XCTest
@testable import OpenWebUI

final class ChatModelsTests: XCTestCase {
    
    // MARK: - Chat Model Tests
    
    func testChatDecoding() throws {
        let json = """
        {
            "id": "chat-123",
            "user_id": "user-456",
            "title": "Test Conversation",
            "model_ids": ["gpt-4", "claude-3"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z",
            "archived": false,
            "pinned": true,
            "tags": ["important", "work"],
            "metadata": {
                "message_count": 10,
                "last_message_at": "2024-01-02T12:00:00Z",
                "system_prompt": "You are a helpful assistant",
                "temperature": 0.8,
                "max_tokens": 2000
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chat = try decoder.decode(Chat.self, from: json)
        
        XCTAssertEqual(chat.id, "chat-123")
        XCTAssertEqual(chat.userId, "user-456")
        XCTAssertEqual(chat.title, "Test Conversation")
        XCTAssertEqual(chat.modelIds, ["gpt-4", "claude-3"])
        XCTAssertFalse(chat.archived)
        XCTAssertTrue(chat.pinned)
        XCTAssertEqual(chat.tags, ["important", "work"])
        XCTAssertEqual(chat.metadata?.messageCount, 10)
        XCTAssertEqual(chat.metadata?.systemPrompt, "You are a helpful assistant")
        XCTAssertEqual(chat.metadata?.temperature, 0.8)
        XCTAssertEqual(chat.metadata?.maxTokens, 2000)
    }
    
    func testChatDecodingWithoutMetadata() throws {
        let json = """
        {
            "id": "chat-123",
            "user_id": "user-456",
            "title": "Test Conversation",
            "model_ids": ["gpt-4"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "archived": false,
            "pinned": false,
            "tags": []
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chat = try decoder.decode(Chat.self, from: json)
        
        XCTAssertEqual(chat.id, "chat-123")
        XCTAssertNil(chat.metadata)
    }
    
    func testChatEquatable() throws {
        let json = """
        {
            "id": "chat-123",
            "user_id": "user-456",
            "title": "Test",
            "model_ids": ["gpt-4"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "archived": false,
            "pinned": false,
            "tags": []
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chat1 = try decoder.decode(Chat.self, from: json)
        let chat2 = try decoder.decode(Chat.self, from: json)
        
        XCTAssertEqual(chat1, chat2)
    }
    
    // MARK: - ChatSession Tests
    
    func testChatSessionInitialization() throws {
        let json = """
        {
            "id": "chat-123",
            "user_id": "user-456",
            "title": "Test",
            "model_ids": ["gpt-4"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "archived": false,
            "pinned": false,
            "tags": [],
            "metadata": {
                "temperature": 0.9,
                "max_tokens": 1500,
                "system_prompt": "Test prompt"
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chat = try decoder.decode(Chat.self, from: json)
        let session = ChatSession(chat: chat)
        
        XCTAssertEqual(session.id, "chat-123")
        XCTAssertEqual(session.temperature, 0.9)
        XCTAssertEqual(session.maxTokens, 1500)
        XCTAssertEqual(session.systemPrompt, "Test prompt")
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertFalse(session.isGenerating)
        XCTAssertFalse(session.enableRAG)
    }
    
    func testChatSessionDefaultValues() throws {
        let json = """
        {
            "id": "chat-123",
            "user_id": "user-456",
            "title": "Test",
            "model_ids": ["gpt-4"],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "archived": false,
            "pinned": false,
            "tags": []
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chat = try decoder.decode(Chat.self, from: json)
        let session = ChatSession(chat: chat)
        
        // Should use default values from AppConfig
        XCTAssertEqual(session.temperature, AppConfig.defaultTemperature)
        XCTAssertEqual(session.maxTokens, AppConfig.defaultMaxTokens)
        XCTAssertNil(session.systemPrompt)
    }
    
    // MARK: - CreateChatRequest Tests
    
    func testCreateChatRequestEncoding() throws {
        let metadata = Chat.ChatMetadata(
            messageCount: nil,
            lastMessageAt: nil,
            systemPrompt: "You are a helpful assistant",
            temperature: 0.7,
            maxTokens: 2000
        )
        
        let request = CreateChatRequest(
            title: "New Chat",
            modelIds: ["gpt-4", "gpt-3.5-turbo"],
            systemPrompt: "You are a helpful assistant",
            metadata: metadata
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["title"] as? String, "New Chat")
        XCTAssertEqual(json["model_ids"] as? [String], ["gpt-4", "gpt-3.5-turbo"])
        XCTAssertEqual(json["system_prompt"] as? String, "You are a helpful assistant")
    }
    
    // MARK: - UpdateChatRequest Tests
    
    func testUpdateChatRequestEncoding() throws {
        let request = UpdateChatRequest(
            title: "Updated Title",
            archived: true,
            pinned: false,
            tags: ["new-tag"],
            metadata: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["title"] as? String, "Updated Title")
        XCTAssertEqual(json["archived"] as? Bool, true)
        XCTAssertEqual(json["pinned"] as? Bool, false)
        XCTAssertEqual(json["tags"] as? [String], ["new-tag"])
    }
    
    // MARK: - ChatsListResponse Tests
    
    func testChatsListResponseDecoding() throws {
        let json = """
        {
            "chats": [
                {
                    "id": "chat-1",
                    "user_id": "user-1",
                    "title": "Chat 1",
                    "model_ids": ["gpt-4"],
                    "created_at": "2024-01-01T00:00:00Z",
                    "updated_at": "2024-01-01T00:00:00Z",
                    "archived": false,
                    "pinned": false,
                    "tags": []
                },
                {
                    "id": "chat-2",
                    "user_id": "user-1",
                    "title": "Chat 2",
                    "model_ids": ["gpt-3.5-turbo"],
                    "created_at": "2024-01-02T00:00:00Z",
                    "updated_at": "2024-01-02T00:00:00Z",
                    "archived": false,
                    "pinned": true,
                    "tags": ["important"]
                }
            ],
            "total": 50,
            "page": 1,
            "page_size": 20
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(ChatsListResponse.self, from: json)
        
        XCTAssertEqual(response.chats.count, 2)
        XCTAssertEqual(response.total, 50)
        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.pageSize, 20)
        XCTAssertEqual(response.chats[0].title, "Chat 1")
        XCTAssertEqual(response.chats[1].title, "Chat 2")
    }
    
    // MARK: - ConversationContext Tests
    
    func testConversationContextToAPIMessages() throws {
        let messages = [
            Message(
                id: "msg-1",
                chatId: "chat-1",
                role: .user,
                content: "Hello",
                modelId: nil,
                timestamp: Date(),
                metadata: nil
            ),
            Message(
                id: "msg-2",
                chatId: "chat-1",
                role: .assistant,
                content: "Hi there!",
                modelId: "gpt-4",
                timestamp: Date(),
                metadata: nil
            )
        ]
        
        let context = ConversationContext(
            messages: messages,
            systemPrompt: "You are a helpful assistant",
            documents: nil,
            tools: nil,
            temperature: 0.7,
            maxTokens: 2000
        )
        
        let apiMessages = context.toAPIMessages()
        
        XCTAssertEqual(apiMessages.count, 3) // system + 2 messages
        XCTAssertEqual(apiMessages[0].role, "system")
        XCTAssertEqual(apiMessages[0].content, "You are a helpful assistant")
        XCTAssertEqual(apiMessages[1].role, "user")
        XCTAssertEqual(apiMessages[1].content, "Hello")
        XCTAssertEqual(apiMessages[2].role, "assistant")
        XCTAssertEqual(apiMessages[2].content, "Hi there!")
    }
    
    func testConversationContextWithoutSystemPrompt() {
        let messages = [
            Message(
                id: "msg-1",
                chatId: "chat-1",
                role: .user,
                content: "Hello",
                modelId: nil,
                timestamp: Date(),
                metadata: nil
            )
        ]
        
        let context = ConversationContext(
            messages: messages,
            systemPrompt: nil,
            documents: nil,
            tools: nil,
            temperature: 0.7,
            maxTokens: 2000
        )
        
        let apiMessages = context.toAPIMessages()
        
        XCTAssertEqual(apiMessages.count, 1) // No system message
        XCTAssertEqual(apiMessages[0].role, "user")
    }
    
    // MARK: - ChatStatistics Tests
    
    func testChatStatisticsDecoding() throws {
        let json = """
        {
            "total_chats": 100,
            "total_messages": 5000,
            "total_tokens": 1000000,
            "favorite_models": ["gpt-4", "claude-3-opus", "llama-3.1"]
        }
        """.data(using: .utf8)!
        
        let stats = try JSONDecoder().decode(ChatStatistics.self, from: json)
        
        XCTAssertEqual(stats.totalChats, 100)
        XCTAssertEqual(stats.totalMessages, 5000)
        XCTAssertEqual(stats.totalTokens, 1000000)
        XCTAssertEqual(stats.favoriteModels, ["gpt-4", "claude-3-opus", "llama-3.1"])
    }
}
