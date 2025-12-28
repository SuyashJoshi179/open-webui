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
    
    @State private var title = ""
    @State private var selectedModelIds: Set<String> = []
    @State private var systemPrompt = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Chat Title") {
                    TextField("Enter title", text: $title)
                }
                
                Section("Select Models") {
                    if viewModel.isLoadingModels {
                        ProgressView()
                    } else if viewModel.availableLocalModels.isEmpty && viewModel.availableCloudModels.isEmpty {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "cube.transparent")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Models Available")
                                .font(.headline)
                            Text("Configure an external API in Settings to use cloud models")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        // Local models (Apple Intelligence)
                        if !viewModel.availableLocalModels.isEmpty {
                            ForEach(viewModel.availableLocalModels) { model in
                                MultipleSelectionRow(
                                    title: model.name,
                                    subtitle: "On-Device",
                                    isSelected: selectedModelIds.contains(model.id)
                                ) {
                                    if selectedModelIds.contains(model.id) {
                                        selectedModelIds.remove(model.id)
                                    } else {
                                        selectedModelIds.insert(model.id)
                                    }
                                }
                            }
                        }
                        
                        // Cloud models
                        if !viewModel.availableCloudModels.isEmpty {
                            ForEach(viewModel.availableCloudModels) { model in
                                MultipleSelectionRow(
                                    title: model.name,
                                    subtitle: "Cloud",
                                    isSelected: selectedModelIds.contains(model.id)
                                ) {
                                    if selectedModelIds.contains(model.id) {
                                        selectedModelIds.remove(model.id)
                                    } else {
                                        selectedModelIds.insert(model.id)
                                    }
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
            .onAppear {
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
    @Published var availableLocalModels: [LocalModel] = []
    @Published var availableCloudModels: [Model] = []
    @Published var isLoadingModels = false
    
    @AppStorage("externalAPIURL") private var externalAPIURL = ""
    @AppStorage("externalAPIKey") private var externalAPIKey = ""
    
    private let apiClient = APIClient.shared
    private let openAIService = OpenAIService.shared
    
    func loadModels() async {
        isLoadingModels = true
        
        // Load local models (Apple Intelligence)
        if #available(iOS 26.0, *) {
            let mlxService = MLXService.shared
            availableLocalModels = mlxService.listLocalModels()
        }
        
        // Only load cloud models if user has configured an external API
        if !externalAPIURL.isEmpty && !externalAPIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                availableCloudModels = try await openAIService.listModels()
            } catch {
                print("Error loading cloud models: \(error)")
                availableCloudModels = []
            }
        } else {
            availableCloudModels = []
        }
        
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
