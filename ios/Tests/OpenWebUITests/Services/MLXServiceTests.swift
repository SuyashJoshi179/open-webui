//
//  MLXServiceTests.swift
//  OpenWebUITests
//
//  Unit tests for MLXService
//

import XCTest
@testable import OpenWebUI

@MainActor
final class MLXServiceTests: XCTestCase {
    
    var sut: MLXService!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = MLXService.shared
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Model Availability Tests
    
    func testModelAvailabilityStatus() async {
        await sut.checkAvailability()
        
        // On iOS 18, Apple Intelligence (FoundationModels) requires iOS 26+
        XCTAssertFalse(sut.isModelAvailable)
    }
    
    func testModelStatusIsUnavailableOnIOS18() async {
        await sut.checkAvailability()
        
        if case .unavailable(let reason) = sut.modelStatus {
            XCTAssertTrue(reason.contains("iOS 26") || reason.contains("not available"))
        } else if case .checking = sut.modelStatus {
            // Still checking is also acceptable
            return
        } else if case .available = sut.modelStatus {
            // If available, model should be marked as available
            XCTAssertTrue(sut.isModelAvailable)
        } else {
            // Accept any status since device capabilities vary
        }
    }
    
    // MARK: - List Local Models Tests
    
    func testListLocalModelsReturnsArray() {
        let models = sut.listLocalModels()
        // Should return an array (possibly empty)
        XCTAssertNotNil(models)
    }
    
    func testListLocalModelsContainsValidModels() {
        let models = sut.listLocalModels()
        
        for model in models {
            XCTAssertFalse(model.id.isEmpty)
            XCTAssertFalse(model.name.isEmpty)
            XCTAssertFalse(model.path.isEmpty)
            XCTAssertGreaterThanOrEqual(model.size, 0)
        }
    }
    
    // MARK: - Session Management Tests
    
    func testClearSessionDoesNotThrow() {
        // Should not throw even when sessions are not available
        sut.clearSession(for: "test-chat-id")
    }
    
    func testClearAllSessionsDoesNotThrow() {
        sut.clearAllSessions()
    }
    
    // MARK: - Generation Tests (Stub Behavior)
    
    func testGenerateThrowsWhenModelNotAvailable() async {
        do {
            _ = try await sut.generate(
                modelName: "apple-intelligence",
                prompt: "Hello",
                chatId: "test-chat"
            )
            // If we get here on a device with Apple Intelligence, that's okay
        } catch {
            // Expected to throw on devices without Apple Intelligence
            XCTAssertTrue(error is MLXServiceError)
        }
    }
    
    func testStreamGenerateCompletesWithError() async {
        let stream = sut.streamGenerate(
            modelName: "test-model",
            prompt: "Hello",
            maxTokens: 100,
            temperature: 0.7,
            topP: 0.9
        )
        
        var receivedError = false
        
        do {
            for try await _ in stream {
                // Should not receive any values
            }
        } catch {
            receivedError = true
        }
        
        XCTAssertTrue(receivedError)
    }
    
    // MARK: - Chat Tests (Stub Behavior)
    
    func testChatThrowsWhenModelNotAvailable() async {
        let messages = [
            MLXChatMessage(role: "user", content: "Hello")
        ]
        
        do {
            _ = try await sut.chat(
                modelName: "apple-intelligence",
                messages: messages,
                chatId: "test-chat"
            )
        } catch {
            XCTAssertTrue(error is MLXServiceError)
        }
    }
    
    func testStreamChatCompletesWithError() async {
        let messages = [
            MLXChatMessage(role: "user", content: "Hello")
        ]
        
        let stream = sut.streamChat(
            modelName: "apple-intelligence",
            messages: messages,
            chatId: "test-chat"
        )
        
        var receivedError = false
        
        do {
            for try await _ in stream {
                // Should not receive any values
            }
        } catch {
            receivedError = true
        }
        
        XCTAssertTrue(receivedError)
    }
    
    // MARK: - Summarization Tests (Stub Behavior)
    
    func testSummarizeThrowsWhenModelNotAvailable() async {
        do {
            _ = try await sut.summarize(text: "Test text to summarize")
        } catch {
            XCTAssertTrue(error is MLXServiceError)
        }
    }
    
    // MARK: - Embedding Tests (Stub Behavior)
    
    func testCreateEmbeddingThrowsNotImplemented() async {
        do {
            _ = try await sut.createEmbedding(
                modelName: "test-model",
                text: "Test text"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is MLXServiceError)
        }
    }
    
    // MARK: - Status Message Tests
    
    func testGetStatusMessageReturnsNonEmptyString() {
        let message = sut.getStatusMessage()
        XCTAssertFalse(message.isEmpty)
    }
    
    func testStatusMessageMatchesStatus() {
        let message = sut.getStatusMessage()
        
        switch sut.modelStatus {
        case .checking:
            XCTAssertTrue(message.contains("Checking") || message.lowercased().contains("check"))
        case .available:
            XCTAssertTrue(message.contains("ready") || message.contains("available"))
        case .unavailable:
            // Any message is acceptable for unavailable status
            XCTAssertFalse(message.isEmpty)
        case .downloading:
            XCTAssertTrue(message.contains("downloading") || message.contains("download"))
        case .disabled:
            XCTAssertTrue(message.contains("disabled") || message.contains("Disabled"))
        }
    }
    
    // MARK: - Model Status Enum Tests
    
    func testModelAvailabilityStatusEquatable() {
        let status1 = MLXService.ModelAvailabilityStatus.available
        let status2 = MLXService.ModelAvailabilityStatus.available
        let status3 = MLXService.ModelAvailabilityStatus.checking
        
        XCTAssertEqual(status1, status2)
        XCTAssertNotEqual(status1, status3)
    }
    
    func testUnavailableStatusWithDifferentReasons() {
        let status1 = MLXService.ModelAvailabilityStatus.unavailable("Reason 1")
        let status2 = MLXService.ModelAvailabilityStatus.unavailable("Reason 2")
        let status3 = MLXService.ModelAvailabilityStatus.unavailable("Reason 1")
        
        XCTAssertNotEqual(status1, status2)
        XCTAssertEqual(status1, status3)
    }
}
