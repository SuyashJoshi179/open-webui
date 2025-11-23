//
//  ChatsListView.swift
//  OpenWebUI
//
//  List of all chats
//

import SwiftUI

struct ChatsListView: View {
    @StateObject private var viewModel = ChatsListViewModel()
    @State private var showNewChat = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.chats.isEmpty {
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
            }
            .refreshable {
                await viewModel.loadChats()
            }
            .onAppear {
                Task {
                    await viewModel.loadChats()
                }
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
            ForEach(viewModel.chats) { chat in
                NavigationLink(destination: ChatView(chat: chat)) {
                    ChatRowView(chat: chat)
                }
            }
            .onDelete { indexSet in
                Task {
                    await viewModel.deleteChats(at: indexSet)
                }
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

// MARK: - View Model

@MainActor
class ChatsListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadChats() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: ChatsListResponse = try await apiClient.request(
                path: "/api/chats"
            )
            chats = response.chats
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteChats(at offsets: IndexSet) async {
        for index in offsets {
            let chat = chats[index]
            do {
                let _: EmptyResponse = try await apiClient.request(
                    path: "/api/chats/\(chat.id)",
                    method: "DELETE"
                )
                chats.remove(at: index)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ChatsListView()
}
