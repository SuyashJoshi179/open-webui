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
    
    private let storageKey = "saved_chats"
    private let defaults = UserDefaults.standard
    
    private init() {
        loadChats()
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
            updatedAt: Date(),
            messages: []
        )
        saveChat(chat)
        return chat
    }
    
    // MARK: - Private Methods
    
    private func persistChats() {
        if let encoded = try? JSONEncoder().encode(chats) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
    
    private func createWelcomeChat() {
        let welcomeChat = Chat(
            id: "welcome",
            title: "Welcome to Open WebUI",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [
                Message(
                    id: "welcome-1",
                    role: .assistant,
                    content: "👋 Welcome to Open WebUI for iOS!\n\nThis app uses Apple Intelligence to provide on-device AI assistance. Your conversations stay completely private on your iPhone.\n\nTap the ✏️ button to start a new chat!",
                    timestamp: Date()
                )
            ]
        )
        chats = [welcomeChat]
        persistChats()
    }
}
