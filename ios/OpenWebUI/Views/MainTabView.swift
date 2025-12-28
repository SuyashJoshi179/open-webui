//
//  MainTabView.swift
//  OpenWebUI
//
//  Main tab navigation
//

import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            ChatsListView()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(0)
            
            ModelsView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
                .tag(1)
            
            DocumentsView()
                .tabItem {
                    Label("Documents", systemImage: "doc.text")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
