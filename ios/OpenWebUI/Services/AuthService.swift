//
//  AuthService.swift
//  OpenWebUI
//
//  Authentication service
//

import Foundation
import Combine

@MainActor
public class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: User?
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Check if user is already authenticated
        checkAuthStatus()
    }
    
    // MARK: - Authentication
    
    func login(email: String, password: String) async throws {
        let request = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await apiClient.request(
            path: "/api/auths/signin",
            method: "POST",
            body: request
        )
        
        apiClient.setAuthToken(response.token)
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
    }
    
    func signup(email: String, password: String, name: String) async throws {
        let request = SignupRequest(email: email, password: password, name: name)
        let response: AuthResponse = try await apiClient.request(
            path: "/api/auths/signup",
            method: "POST",
            body: request
        )
        
        apiClient.setAuthToken(response.token)
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
    }
    
    func logout() {
        apiClient.setAuthToken(nil)
        
        currentUser = nil
        isAuthenticated = false
    }
    
    func refreshToken() async throws {
        // Implement token refresh if backend supports it
        let user: User = try await apiClient.request(path: "/api/auths/me")
        
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthStatus() {
        // Check if we have a saved token
        if let _ = KeychainHelper.load(forKey: "auth_token") {
            Task {
                do {
                    try await refreshToken()
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                } catch {
                    // Token is invalid, clear it
                    logout()
                }
            }
        }
    }
}
