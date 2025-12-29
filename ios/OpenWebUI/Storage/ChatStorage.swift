//
//  ChatStorage.swift
//  OpenWebUI
//
//  Local storage for chats using UserDefaults/FileManager
//

import Foundation

@MainActor
public class ChatStorage: ObservableObject {
    public static let shared = ChatStorage()
    
    @Published public private(set) var chats: [Chat] = []
    private var chatMessages: [String: [Message]] = [:] // chatId -> messages
    
    private let storageKey = "saved_chats"
    private let messagesKey = "saved_messages"
    private let defaults = UserDefaults.standard
    
    private init() {
        loadChats()
        loadMessages()
    }
    
    // MARK: - Public Methods
    
    public func loadChats() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Chat].self, from: data) {
            chats = decoded.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            // Create a default welcome chat
            createWelcomeChat()
        }
    }
    
    public func saveChat(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
        } else {
            chats.insert(chat, at: 0)
        }
        persistChats()
    }
    
    public func deleteChat(_ chat: Chat) {
        chats.removeAll { $0.id == chat.id }
        deleteMessages(for: chat.id)
        persistChats()
    }
    
    public func deleteChats(at offsets: IndexSet) {
        chats.remove(atOffsets: offsets)
        persistChats()
    }
    
    public func createNewChat(title: String = "New Chat") -> Chat {
        let chat = Chat(
            id: UUID().uuidString,
            title: title,
            createdAt: Date(),
            updatedAt: Date()
        )
        saveChat(chat)
        return chat
    }
    
    // MARK: - Message Management
    
    public func getMessages(for chatId: String) -> [Message] {
        return chatMessages[chatId] ?? []
    }
    
    public func saveMessages(_ messages: [Message], for chatId: String) {
        chatMessages[chatId] = messages
        persistMessages()
        
        // Update chat's updatedAt timestamp
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            let updatedChat = Chat(
                id: chats[index].id,
                userId: chats[index].userId,
                title: chats[index].title,
                modelIds: chats[index].modelIds,
                createdAt: chats[index].createdAt,
                updatedAt: Date(),
                archived: chats[index].archived,
                pinned: chats[index].pinned,
                tags: chats[index].tags,
                metadata: chats[index].metadata
            )
            chats[index] = updatedChat
            persistChats()
        }
    }
    
    public func deleteMessages(for chatId: String) {
        chatMessages.removeValue(forKey: chatId)
        persistMessages()
    }
    
    // MARK: - Private Methods
    
    private func persistChats() {
        if let encoded = try? JSONEncoder().encode(chats) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
    
    private func persistMessages() {
        if let encoded = try? JSONEncoder().encode(chatMessages) {
            defaults.set(encoded, forKey: messagesKey)
        }
    }
    
    private func loadMessages() {
        if let data = defaults.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([String: [Message]].self, from: data) {
            chatMessages = decoded
        }
    }
    
    private func createWelcomeChat() {
        let welcomeChat = Chat(
            id: "welcome",
            title: "Welcome to Open WebUI",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let welcomeMessage = Message(
            id: "welcome-1",
            chatId: "welcome",
            role: .assistant,
            content: "👋 Welcome to Open WebUI for iOS!\n\nThis app uses Apple Intelligence to provide on-device AI assistance. Your conversations stay completely private on your iPhone.\n\nTap the ✏️ button to start a new chat!",
            timestamp: Date()
        )
        
        chats = [welcomeChat]
        chatMessages["welcome"] = [welcomeMessage]
        persistChats()
        persistMessages()
    }
}
