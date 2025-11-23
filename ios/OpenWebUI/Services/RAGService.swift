//
//  RAGService.swift
//  OpenWebUI
//
//  Retrieval Augmented Generation (RAG) service
//

import Foundation

class RAGService {
    static let shared = RAGService()
    
    private let apiClient = APIClient.shared
    private let documentsDirectory = AppConfig.documentsDirectory
    
    private init() {
        createDocumentsDirectoryIfNeeded()
    }
    
    // MARK: - Document Management
    
    func uploadDocument(
        fileURL: URL,
        knowledgeBaseId: String? = nil
    ) async throws -> Document {
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let mimeType = mimeType(for: fileURL.pathExtension)
        
        var fields: [String: String] = [:]
        if let knowledgeBaseId = knowledgeBaseId {
            fields["knowledge_base_id"] = knowledgeBaseId
        }
        
        return try await apiClient.upload(
            path: "/api/retrieval/upload",
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            additionalFields: fields
        )
    }
    
    func listDocuments() async throws -> [Document] {
        let response: DocumentsResponse = try await apiClient.request(
            path: "/api/retrieval/documents"
        )
        return response.documents
    }
    
    func getDocument(id: String) async throws -> Document {
        return try await apiClient.request(
            path: "/api/retrieval/documents/\(id)"
        )
    }
    
    func deleteDocument(id: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            path: "/api/retrieval/documents/\(id)",
            method: "DELETE"
        )
    }
    
    // MARK: - Knowledge Base Management
    
    func createKnowledgeBase(
        name: String,
        description: String?,
        documentIds: [String]
    ) async throws -> KnowledgeBase {
        let request = CreateKnowledgeBaseRequest(
            name: name,
            description: description,
            documentIds: documentIds
        )
        
        return try await apiClient.request(
            path: "/api/knowledge",
            method: "POST",
            body: request
        )
    }
    
    func listKnowledgeBases() async throws -> [KnowledgeBase] {
        let response: KnowledgeBasesResponse = try await apiClient.request(
            path: "/api/knowledge"
        )
        return response.knowledgeBases
    }
    
    func getKnowledgeBase(id: String) async throws -> KnowledgeBase {
        return try await apiClient.request(
            path: "/api/knowledge/\(id)"
        )
    }
    
    func updateKnowledgeBase(
        id: String,
        name: String?,
        description: String?,
        documentIds: [String]?
    ) async throws -> KnowledgeBase {
        let request = UpdateKnowledgeBaseRequest(
            name: name,
            description: description,
            documentIds: documentIds
        )
        
        return try await apiClient.request(
            path: "/api/knowledge/\(id)",
            method: "PUT",
            body: request
        )
    }
    
    func deleteKnowledgeBase(id: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            path: "/api/knowledge/\(id)",
            method: "DELETE"
        )
    }
    
    // MARK: - Query
    
    func query(
        text: String,
        knowledgeBaseId: String? = nil,
        topK: Int = 5
    ) async throws -> [SearchResult] {
        let request = QueryRequest(
            query: text,
            knowledgeBaseId: knowledgeBaseId,
            topK: topK
        )
        
        let response: QueryResponse = try await apiClient.request(
            path: "/api/retrieval/query",
            method: "POST",
            body: request
        )
        
        return response.results
    }
    
    // MARK: - Local Document Processing
    
    func processDocumentLocally(_ fileURL: URL) async throws -> ProcessedDocument {
        // This would process documents locally for offline RAG
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Extract text based on file type
        let text = try await extractText(from: fileData, fileType: fileExtension)
        
        // Chunk the text
        let chunks = chunkText(text, chunkSize: AppConfig.chunkSize, overlap: AppConfig.chunkOverlap)
        
        return ProcessedDocument(
            fileName: fileName,
            fileType: fileExtension,
            text: text,
            chunks: chunks
        )
    }
    
    // MARK: - Private Methods
    
    private func createDocumentsDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: documentsDirectory.path) {
            try? FileManager.default.createDirectory(
                at: documentsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
    
    private func extractText(from data: Data, fileType: String) async throws -> String {
        // Placeholder for text extraction
        // In a real implementation, you would use different parsers based on file type
        switch fileType {
        case "txt", "md":
            return String(data: data, encoding: .utf8) ?? ""
        case "pdf":
            // Use PDFKit or similar
            throw RAGServiceError.unsupportedFileType(fileType)
        case "docx":
            // Use appropriate parser
            throw RAGServiceError.unsupportedFileType(fileType)
        default:
            throw RAGServiceError.unsupportedFileType(fileType)
        }
    }
    
    private func chunkText(_ text: String, chunkSize: Int, overlap: Int) -> [String] {
        var chunks: [String] = []
        let words = text.split(separator: " ").map(String.init)
        
        var currentIndex = 0
        while currentIndex < words.count {
            let endIndex = min(currentIndex + chunkSize, words.count)
            let chunk = words[currentIndex..<endIndex].joined(separator: " ")
            chunks.append(chunk)
            
            currentIndex += chunkSize - overlap
        }
        
        return chunks
    }
    
    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "md": return "text/markdown"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Supporting Types

struct DocumentsResponse: Codable {
    let documents: [Document]
}

struct KnowledgeBasesResponse: Codable {
    let knowledgeBases: [KnowledgeBase]
    
    enum CodingKeys: String, CodingKey {
        case knowledgeBases = "knowledge_bases"
    }
}

struct CreateKnowledgeBaseRequest: Codable {
    let name: String
    let description: String?
    let documentIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case documentIds = "document_ids"
    }
}

struct UpdateKnowledgeBaseRequest: Codable {
    let name: String?
    let description: String?
    let documentIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case documentIds = "document_ids"
    }
}

struct QueryRequest: Codable {
    let query: String
    let knowledgeBaseId: String?
    let topK: Int
    
    enum CodingKeys: String, CodingKey {
        case query
        case knowledgeBaseId = "knowledge_base_id"
        case topK = "top_k"
    }
}

struct QueryResponse: Codable {
    let results: [SearchResult]
}

struct SearchResult: Codable, Identifiable {
    let id: String
    let documentId: String
    let content: String
    let score: Float
    let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case documentId = "document_id"
        case content
        case score
        case metadata
    }
}

struct ProcessedDocument {
    let fileName: String
    let fileType: String
    let text: String
    let chunks: [String]
}

// MARK: - Errors

enum RAGServiceError: LocalizedError {
    case unsupportedFileType(String)
    case processingFailed(String)
    case documentNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let type):
            return "Unsupported file type: \(type)"
        case .processingFailed(let error):
            return "Document processing failed: \(error)"
        case .documentNotFound(let id):
            return "Document not found: \(id)"
        }
    }
}
