//
//  APIClient.swift
//  OpenWebUI
//
//  Core API client for backend communication
//

import Foundation
import Combine

@MainActor
class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let baseURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    // Authentication token
    private(set) var authToken: String? {
        didSet {
            if let token = authToken {
                KeychainHelper.save(token, forKey: "auth_token")
            } else {
                KeychainHelper.delete(forKey: "auth_token")
            }
        }
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.apiTimeout
        config.timeoutIntervalForResource = AppConfig.streamingTimeout
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: AppConfig.backendURL)!
        
        // Load saved auth token
        self.authToken = KeychainHelper.load(forKey: "auth_token")
    }
    
    // MARK: - Authentication
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    // MARK: - Request Building
    
    private func buildRequest(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        headers: [String: String] = [:]
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Encode body if present
        if let body = body {
            request.httpBody = try JSONEncoder.api.encode(body)
        }
        
        return request
    }
    
    // MARK: - Generic Request Methods
    
    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        let request = try buildRequest(path: path, method: method, body: body, headers: headers)
        
        if AppConfig.enableNetworkLogging {
            print("📡 \(method) \(request.url?.absoluteString ?? "")")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        if AppConfig.enableNetworkLogging {
            print("📥 Response: \(httpResponse.statusCode)")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error response
            if let apiError = try? JSONDecoder.api.decode(APIError.self, from: data) {
                throw apiError
            }
            throw APIClientError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder.api.decode(T.self, from: data)
    }
    
    // MARK: - Streaming Request
    
    func stream(
        path: String,
        method: String = "POST",
        body: Encodable? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(path: path, method: method, body: body)
                    
                    if AppConfig.enableNetworkLogging {
                        print("📡 Stream \(method) \(request.url?.absoluteString ?? "")")
                    }
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw APIClientError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw APIClientError.httpError(httpResponse.statusCode)
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            continuation.yield(data)
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Upload
    
    func upload<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String] = [:]
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = baseURL.appendingPathComponent(path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // Add additional fields
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder.api.decode(T.self, from: data)
    }
}

// MARK: - Error Types

enum APIClientError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - JSON Encoder/Decoder Extensions

extension JSONEncoder {
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
