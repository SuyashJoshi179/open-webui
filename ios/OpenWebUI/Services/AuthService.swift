//
//  AuthService.swift
//  OpenWebUI
//
//  Authentication service - Local-only mode (no backend authentication required)
//

import Foundation
import Combine

@MainActor
public class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    // In local-only mode, user is always authenticated
    @Published public var isAuthenticated: Bool = true
    @Published public var currentUser: User? = User(
        id: "local-user",
        email: "local@device",
        name: "Local User",
        role: .user,
        profileImageUrl: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    private init() {
        // App is fully local - no authentication needed
    }
    
    // MARK: - Authentication (Stubbed for local-only mode)
    
    func login(email: String, password: String) async throws {
        // No-op in local mode - already authenticated
        isAuthenticated = true
    }
    
    func signup(email: String, password: String, name: String) async throws {
        // No-op in local mode - already authenticated
        isAuthenticated = true
    }
    
    func logout() {
        // No-op in local mode - can't log out of local device
    }
    
    func refreshToken() async throws {
        // No-op in local mode
    }
}
