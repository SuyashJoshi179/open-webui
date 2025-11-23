//
//  AppConfig.swift
//  OpenWebUI
//
//  Application configuration
//

import Foundation

struct AppConfig {
    // MARK: - Backend Configuration
    
    /// Backend API base URL
    /// Update this to point to your Open WebUI backend instance
    static var backendURL: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://localhost:8080"
        #else
        return ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "https://api.openwebui.com"
        #endif
    }
    
    /// WebSocket URL for real-time features
    static var websocketURL: String {
        let url = backendURL.replacingOccurrences(of: "http", with: "ws")
        return "\(url)/ws"
    }
    
    // MARK: - API Configuration
    
    static let apiTimeout: TimeInterval = 30.0
    static let streamingTimeout: TimeInterval = 300.0
    
    // MARK: - Local Model Configuration
    
    /// Directory for storing downloaded local models
    static var modelsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models", isDirectory: true)
    }
    
    /// Maximum size for model cache (in bytes)
    static let maxModelCacheSize: Int64 = 10_000_000_000 // 10 GB
    
    // MARK: - RAG Configuration
    
    /// Directory for RAG documents
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("documents", isDirectory: true)
    }
    
    /// Maximum document size (in bytes)
    static let maxDocumentSize: Int64 = 50_000_000 // 50 MB
    
    /// Chunk size for document processing
    static let chunkSize: Int = 1000
    
    /// Chunk overlap for document processing
    static let chunkOverlap: Int = 200
    
    // MARK: - Chat Configuration
    
    static let maxChatHistory: Int = 100
    static let defaultTemperature: Double = 0.7
    static let defaultMaxTokens: Int = 2048
    
    // MARK: - Storage Configuration
    
    /// App group identifier for sharing data between app and extensions
    static let appGroupIdentifier = "group.com.openwebui.ios"
    
    // MARK: - Feature Flags
    
    static let enableLocalInference = true
    static let enableRAG = true
    static let enableToolCalling = true
    static let enableImageGeneration = true
    static let enableAudioTranscription = true
    static let enableVoiceInput = true
    
    // MARK: - Debug Configuration
    
    #if DEBUG
    static let enableLogging = true
    static let enableNetworkLogging = true
    #else
    static let enableLogging = false
    static let enableNetworkLogging = false
    #endif
}
