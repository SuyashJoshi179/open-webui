//
//  ChatsListView.swift
//  OpenWebUI
//
//  List of all chats
//

import SwiftUI

struct ChatsListView: View {
    @StateObject private var chatStorage = ChatStorage.shared
    @State private var showNewChat = false
    
    var body: some View {
        NavigationStack {
            Group {
                if chatStorage.chats.isEmpty {
                    emptyState
                } else {
                    chatsList
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
                    .environmentObject(chatStorage)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No chats yet")
                .font(.headline)
            
            Text("Create a new chat to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: { showNewChat = true }) {
                Label("New Chat", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var chatsList: some View {
        List {
            ForEach(chatStorage.chats) { chat in
                NavigationLink(destination: ChatView(chat: chat)) {
                    ChatRowView(chat: chat)
                }
            }
            .onDelete { indexSet in
                chatStorage.deleteChats(at: indexSet)
            }
        }
    }
}

struct ChatRowView: View {
    let chat: Chat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.title)
                .font(.headline)
            
            if let lastMessage = chat.metadata?.lastMessageAt {
                Text(lastMessage, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ChatsListView()
}
