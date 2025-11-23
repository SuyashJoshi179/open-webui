//
//  NewChatView.swift
//  OpenWebUI
//
//  Create new chat
//

import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NewChatViewModel()
    
    @State private var title = ""
    @State private var selectedModels: [Model] = []
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
                    } else {
                        ForEach(viewModel.availableModels) { model in
                            MultipleSelectionRow(
                                title: model.name,
                                isSelected: selectedModels.contains(model)
                            ) {
                                if selectedModels.contains(model) {
                                    selectedModels.removeAll { $0.id == model.id }
                                } else {
                                    selectedModels.append(model)
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
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(title.isEmpty || selectedModels.isEmpty)
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
        Task {
            await viewModel.createChat(
                title: title,
                modelIds: selectedModels.map { $0.id },
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
            )
            dismiss()
        }
    }
}

struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
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
    @Published var availableModels: [Model] = []
    @Published var isLoadingModels = false
    
    private let apiClient = APIClient.shared
    
    func loadModels() async {
        isLoadingModels = true
        
        do {
            let response: ModelsResponse = try await apiClient.request(
                path: "/api/models"
            )
            availableModels = response.data
        } catch {
            print("Error loading models: \(error)")
        }
        
        isLoadingModels = false
    }
    
    func createChat(title: String, modelIds: [String], systemPrompt: String?) async {
        do {
            let request = CreateChatRequest(
                title: title,
                modelIds: modelIds,
                systemPrompt: systemPrompt,
                metadata: nil
            )
            
            let _: Chat = try await apiClient.request(
                path: "/api/chats",
                method: "POST",
                body: request
            )
        } catch {
            print("Error creating chat: \(error)")
        }
    }
}

#Preview {
    NewChatView()
}
