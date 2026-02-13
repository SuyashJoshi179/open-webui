//
//  NewChatView.swift
//  OpenWebUI
//
//  Create new chat
//

import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var chatStorage: ChatStorage
    @StateObject private var viewModel = NewChatViewModel()
    @ObservedObject private var backendManager = BackendManager.shared
    
    @State private var title = ""
    @State private var selectedModelIds: Set<String> = []
    @State private var systemPrompt = ""
    @State private var showingBackendSettings = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Chat Title") {
                    TextField("Enter title", text: $title)
                }
                
                Section("Select Models") {
                    if viewModel.isLoadingModels {
                        ProgressView("Loading models...")
                    } else if viewModel.availableModels.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "cube.transparent")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Models Available")
                                .font(.headline)
                            Text("Configure backends in Settings to enable models")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { showingBackendSettings = true }) {
                                Label("Configure Backends", systemImage: "gearshape")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        // Show active model
                        if let activeModel = backendManager.activeModel {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Using: \(activeModel.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Change") {
                                    showingBackendSettings = true
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Group models by backend
                        ForEach(viewModel.availableModels) { model in
                            MultipleSelectionRow(
                                title: model.displayName,
                                subtitle: model.modelIdentifier,
                                isSelected: selectedModelIds.contains(model.id.uuidString)
                            ) {
                                if selectedModelIds.contains(model.id.uuidString) {
                                    selectedModelIds.remove(model.id.uuidString)
                                } else {
                                    selectedModelIds.insert(model.id.uuidString)
                                }
                            }
                        }
                    }
                }
                
                Section("System Prompt (Optional)") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Chat")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChat()
                    }
                    .disabled(title.isEmpty || selectedModelIds.isEmpty)
                }
            }
            .sheet(isPresented: $showingBackendSettings) {
                NavigationStack {
                    BackendSelectionView()
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadModels()
                }
            }
            .onChange(of: backendManager.allModels.count) { _, _ in
                Task {
                    await viewModel.loadModels()
                    // Clear selection if models changed
                    selectedModelIds.removeAll()
                }
            }
            .onChange(of: backendManager.activeModel?.id) { _, _ in
                Task {
                    await viewModel.loadModels()
                }
            }
        }
    }
    
    private func createChat() {
        viewModel.createChat(
            title: title,
            modelIds: Array(selectedModelIds),
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            chatStorage: chatStorage
        )
        dismiss()
    }
}

struct MultipleSelectionRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

@MainActor
class NewChatViewModel: ObservableObject {
    @Published var availableModels: [ConfiguredAIModel] = []
    @Published var isLoadingModels = false
    
    private let backendManager = BackendManager.shared
    
    func loadModels() async {
        isLoadingModels = true
        
        // Load all available models from all backends
        availableModels = backendManager.allModels
        
        isLoadingModels = false
    }
    
    func createChat(title: String, modelIds: [String], systemPrompt: String?, chatStorage: ChatStorage) {
        // Create the chat with proper metadata
        let metadata = Chat.ChatMetadata(
            messageCount: 0,
            lastMessageAt: nil,
            systemPrompt: systemPrompt,
            temperature: nil,
            maxTokens: nil
        )
        
        let chat = Chat(
            id: UUID().uuidString,
            userId: "local",
            title: title,
            modelIds: modelIds,
            createdAt: Date(),
            updatedAt: Date(),
            archived: false,
            pinned: false,
            tags: [],
            metadata: metadata,
            messages: []
        )
        
        // Save the chat to storage
        chatStorage.saveChat(chat)
        print("✅ Created chat: \(title) with models: \(modelIds)")
    }
}

#Preview {
    NewChatView()
}
