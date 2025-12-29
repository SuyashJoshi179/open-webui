//
//  OpenWebUIApp.swift
//  OpenWebUI
//
//  iOS app entry point (disabled when used as library)
//

import SwiftUI

// Note: @main is disabled because this is now a library
// The actual app entry point is in OpenWebUIApp target
// #if !TESTING
// @main
// #endif
struct OpenWebUIApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService.shared
    
    init() {
        // Configure app on launch
        configureApp()
        
        // Backends are auto-discovered and registered by BackendManager.shared
        // No manual setup needed - BackendManager handles it automatically
    }
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(appState)
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
    
    private func configureApp() {
        // Configure app-wide settings
        setupNetworking()
        setupAppearance()
    }
    
    private func setupNetworking() {
        // Configure URLSession and networking
        URLCache.shared.memoryCapacity = 50_000_000 // 50 MB
        URLCache.shared.diskCapacity = 500_000_000 // 500 MB
    }
    
    private func setupAppearance() {
        // Configure UI appearance
        // Additional setup can be added here
    }
}

/// Global app state
class AppState: ObservableObject {
    @Published var selectedChat: Chat?
    @Published var isOfflineMode: Bool = false
    @Published var networkStatus: NetworkStatus = .online
    
    enum NetworkStatus {
        case online
        case offline
        case unknown
    }
}
