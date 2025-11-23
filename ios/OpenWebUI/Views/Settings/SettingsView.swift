//
//  SettingsView.swift
//  OpenWebUI
//
//  App settings
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("backendURL") private var backendURL = AppConfig.backendURL
    @AppStorage("enableOfflineMode") private var enableOfflineMode = false
    @AppStorage("defaultTemperature") private var defaultTemperature = 0.7
    @AppStorage("defaultMaxTokens") private var defaultMaxTokens = 2048
    
    var body: some View {
        NavigationStack {
            Form {
                // User Section
                Section("Account") {
                    if let user = authService.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Button(role: .destructive, action: logout) {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
                
                // Connection Section
                Section("Connection") {
                    TextField("Backend URL", text: $backendURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    
                    Toggle("Offline Mode", isOn: $enableOfflineMode)
                }
                
                // Model Settings
                Section("Default Model Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", defaultTemperature))
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $defaultTemperature, in: 0...2, step: 0.1)
                    }
                    
                    Stepper("Max Tokens: \(defaultMaxTokens)", value: $defaultMaxTokens, in: 128...8192, step: 128)
                }
                
                // Features Section
                Section("Features") {
                    FeatureToggle(title: "RAG Support", isEnabled: AppConfig.enableRAG)
                    FeatureToggle(title: "Tool Calling", isEnabled: AppConfig.enableToolCalling)
                    FeatureToggle(title: "Image Generation", isEnabled: AppConfig.enableImageGeneration)
                    FeatureToggle(title: "Voice Input", isEnabled: AppConfig.enableVoiceInput)
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/open-webui/open-webui")!) {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(action: clearCache) {
                        Label("Clear Cache", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func logout() {
        authService.logout()
    }
    
    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        // Additional cleanup can be added here
    }
}

struct FeatureToggle: View {
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(isEnabled ? .green : .gray)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
}
