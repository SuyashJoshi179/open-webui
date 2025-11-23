//
//  ToolService.swift
//  OpenWebUI
//
//  Tool/Function calling service
//

import Foundation

class ToolService {
    static let shared = ToolService()
    
    private let apiClient = APIClient.shared
    
    private init() {}
    
    // MARK: - Tool Management
    
    func listTools() async throws -> [Tool] {
        let response: ToolsResponse = try await apiClient.request(
            path: "/api/tools"
        )
        return response.tools
    }
    
    func getTool(id: String) async throws -> Tool {
        return try await apiClient.request(
            path: "/api/tools/\(id)"
        )
    }
    
    func createTool(
        name: String,
        description: String,
        parameters: Tool.ToolParameters,
        code: String
    ) async throws -> Tool {
        let request = CreateToolRequest(
            name: name,
            description: description,
            parameters: parameters,
            code: code
        )
        
        return try await apiClient.request(
            path: "/api/tools",
            method: "POST",
            body: request
        )
    }
    
    func updateTool(
        id: String,
        name: String?,
        description: String?,
        parameters: Tool.ToolParameters?,
        code: String?,
        enabled: Bool?
    ) async throws -> Tool {
        let request = UpdateToolRequest(
            name: name,
            description: description,
            parameters: parameters,
            code: code,
            enabled: enabled
        )
        
        return try await apiClient.request(
            path: "/api/tools/\(id)",
            method: "PUT",
            body: request
        )
    }
    
    func deleteTool(id: String) async throws {
        let _: EmptyResponse = try await apiClient.request(
            path: "/api/tools/\(id)",
            method: "DELETE"
        )
    }
    
    // MARK: - Tool Execution
    
    func executeTool(
        id: String,
        arguments: [String: Any]
    ) async throws -> ToolExecutionResult {
        let request = ExecuteToolRequest(
            toolId: id,
            arguments: arguments
        )
        
        return try await apiClient.request(
            path: "/api/tools/execute",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Function Calling
    
    func handleFunctionCall(
        functionName: String,
        arguments: String,
        availableTools: [Tool]
    ) async throws -> String {
        // Find the tool
        guard let tool = availableTools.first(where: { $0.name == functionName }) else {
            throw ToolServiceError.toolNotFound(functionName)
        }
        
        // Parse arguments
        guard let argumentsData = arguments.data(using: .utf8),
              let argumentsDict = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            throw ToolServiceError.invalidArguments
        }
        
        // Execute the tool
        let result = try await executeTool(id: tool.id, arguments: argumentsDict)
        
        return result.result
    }
}

// MARK: - Supporting Types

struct ToolsResponse: Codable {
    let tools: [Tool]
}

struct CreateToolRequest: Codable {
    let name: String
    let description: String
    let parameters: Tool.ToolParameters
    let code: String
}

struct UpdateToolRequest: Codable {
    let name: String?
    let description: String?
    let parameters: Tool.ToolParameters?
    let code: String?
    let enabled: Bool?
}

struct ExecuteToolRequest: Codable {
    let toolId: String
    let arguments: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case toolId = "tool_id"
        case arguments
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolId, forKey: .toolId)
        
        // Encode arguments as JSON
        let argumentsData = try JSONSerialization.data(withJSONObject: arguments)
        let argumentsString = String(data: argumentsData, encoding: .utf8) ?? "{}"
        try container.encode(argumentsString, forKey: .arguments)
    }
}

struct ToolExecutionResult: Codable {
    let success: Bool
    let result: String
    let error: String?
    let executionTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case success
        case result
        case error
        case executionTime = "execution_time"
    }
}

// MARK: - Errors

enum ToolServiceError: LocalizedError {
    case toolNotFound(String)
    case invalidArguments
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .invalidArguments:
            return "Invalid tool arguments"
        case .executionFailed(let error):
            return "Tool execution failed: \(error)"
        }
    }
}
