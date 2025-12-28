//
//  OpenWebUIAppApp.swift
//  OpenWebUIApp
//
//  Main app entry point
//

import SwiftUI
import OpenWebUI

@main
struct OpenWebUIAppApp: App {
    @StateObject private var authService = AuthService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}

/// Simple wrapper view that handles authentication flow
struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        // Skip authentication - go directly to main app
        MainTabView()
            .environmentObject(authService)
    }
}
