//
//  AppConfigTests.swift
//  OpenWebUITests
//
//  Unit tests for AppConfig
//

import XCTest
@testable import OpenWebUI

final class AppConfigTests: XCTestCase {
    
    // MARK: - Backend Configuration Tests
    
    func testBackendURLIsNotEmpty() {
        XCTAssertFalse(AppConfig.backendURL.isEmpty)
    }
    
    func testBackendURLStartsWithHTTP() {
        XCTAssertTrue(
            AppConfig.backendURL.hasPrefix("http://") || 
            AppConfig.backendURL.hasPrefix("https://")
        )
    }
    
    func testWebsocketURLIsValid() {
        let wsURL = AppConfig.websocketURL
        XCTAssertTrue(
            wsURL.hasPrefix("ws://") || 
            wsURL.hasPrefix("wss://")
        )
        XCTAssertTrue(wsURL.hasSuffix("/ws"))
    }
    
    func testWebsocketURLConvertsHTTPToWS() {
        // The websocket URL should be derived from backend URL
        if AppConfig.backendURL.hasPrefix("https://") {
            XCTAssertTrue(AppConfig.websocketURL.hasPrefix("wss://"))
        } else if AppConfig.backendURL.hasPrefix("http://") {
            XCTAssertTrue(AppConfig.websocketURL.hasPrefix("ws://"))
        }
    }
    
    // MARK: - API Configuration Tests
    
    func testAPITimeoutIsPositive() {
        XCTAssertGreaterThan(AppConfig.apiTimeout, 0)
    }
    
    func testStreamingTimeoutIsGreaterThanAPITimeout() {
        XCTAssertGreaterThan(AppConfig.streamingTimeout, AppConfig.apiTimeout)
    }
    
    func testTimeoutsAreReasonable() {
        // API timeout should be at least 10 seconds
        XCTAssertGreaterThanOrEqual(AppConfig.apiTimeout, 10)
        // Streaming timeout should be at least 60 seconds
        XCTAssertGreaterThanOrEqual(AppConfig.streamingTimeout, 60)
    }
    
    // MARK: - Directory Configuration Tests
    
    func testModelsDirectoryURL() {
        let directory = AppConfig.modelsDirectory
        XCTAssertTrue(directory.path.contains("models"))
    }
    
    func testDocumentsDirectoryURL() {
        let directory = AppConfig.documentsDirectory
        XCTAssertTrue(directory.path.contains("documents"))
    }
    
    func testMaxModelCacheSizeIsPositive() {
        XCTAssertGreaterThan(AppConfig.maxModelCacheSize, 0)
    }
    
    func testMaxModelCacheSizeIsReasonable() {
        // At least 1 GB
        XCTAssertGreaterThanOrEqual(AppConfig.maxModelCacheSize, 1_000_000_000)
    }
    
    // MARK: - RAG Configuration Tests
    
    func testMaxDocumentSizeIsPositive() {
        XCTAssertGreaterThan(AppConfig.maxDocumentSize, 0)
    }
    
    func testChunkSizeIsPositive() {
        XCTAssertGreaterThan(AppConfig.chunkSize, 0)
    }
    
    func testChunkOverlapIsLessThanChunkSize() {
        XCTAssertLessThan(AppConfig.chunkOverlap, AppConfig.chunkSize)
    }
    
    func testChunkOverlapIsNonNegative() {
        XCTAssertGreaterThanOrEqual(AppConfig.chunkOverlap, 0)
    }
    
    // MARK: - Chat Configuration Tests
    
    func testMaxChatHistoryIsPositive() {
        XCTAssertGreaterThan(AppConfig.maxChatHistory, 0)
    }
    
    func testDefaultTemperatureIsInValidRange() {
        XCTAssertGreaterThanOrEqual(AppConfig.defaultTemperature, 0.0)
        XCTAssertLessThanOrEqual(AppConfig.defaultTemperature, 2.0)
    }
    
    func testDefaultMaxTokensIsPositive() {
        XCTAssertGreaterThan(AppConfig.defaultMaxTokens, 0)
    }
    
    func testDefaultMaxTokensIsReasonable() {
        // Should be at least 256 tokens
        XCTAssertGreaterThanOrEqual(AppConfig.defaultMaxTokens, 256)
        // Should not exceed common model limits
        XCTAssertLessThanOrEqual(AppConfig.defaultMaxTokens, 128_000)
    }
    
    // MARK: - Storage Configuration Tests
    
    func testAppGroupIdentifierIsNotEmpty() {
        XCTAssertFalse(AppConfig.appGroupIdentifier.isEmpty)
    }
    
    func testAppGroupIdentifierHasValidFormat() {
        XCTAssertTrue(AppConfig.appGroupIdentifier.hasPrefix("group."))
    }
    
    // MARK: - Feature Flags Tests
    
    func testFeatureFlagsAreBoolean() {
        // These should compile and be boolean values
        let _: Bool = AppConfig.enableLocalInference
        let _: Bool = AppConfig.enableRAG
        let _: Bool = AppConfig.enableToolCalling
        let _: Bool = AppConfig.enableImageGeneration
        let _: Bool = AppConfig.enableAudioTranscription
        let _: Bool = AppConfig.enableVoiceInput
    }
    
    // MARK: - Debug Configuration Tests
    
    func testLoggingFlagsAreBoolean() {
        let _: Bool = AppConfig.enableLogging
        let _: Bool = AppConfig.enableNetworkLogging
    }
    
    #if DEBUG
    func testDebugLoggingIsEnabledInDebugMode() {
        XCTAssertTrue(AppConfig.enableLogging)
        XCTAssertTrue(AppConfig.enableNetworkLogging)
    }
    #endif
}
