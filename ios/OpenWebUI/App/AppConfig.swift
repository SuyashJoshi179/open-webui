//
//  AppConfig.swift
//  OpenWebUI
//
//  Application configuration
//

import Foundation

struct AppConfig {
    // MARK: - Local Backend Configuration
    // This app is fully self-contained with local AI backends (LiteRT, LlamaCpp, Apple Foundation)
    // No external backend server is required
    
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
