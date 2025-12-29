//
//  BackendSelectionView.swift
//  OpenWebUI
//
//  View for selecting and managing AI backends
//

import SwiftUI

struct BackendSelectionView: View {
    @StateObject private var backendManager = BackendManager.shared
    @State private var selectedBackendId: String?
    @State private var showingSettings = false
    @State private var settingsBackend: AIBackend?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            Section {
                if let activeBackend = backendManager.activeBackend {
                    activeBackendCard(activeBackend)
                } else {
                    Text("No backend selected")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            } header: {
                Text("Active Backend")
            }
            
            Section {
                ForEach(backendManager.availableBackends, id: \.id) { backend in
                    BackendRow(
                        backend: backend,
                        isActive: backend.id == backendManager.activeBackend?.id,
                        onSelect: {
                            Task {
                                await selectBackend(backend)
                            }
                        },
                        onSettings: {
                            settingsBackend = backend
                            showingSettings = true
                        }
                    )
                }
            } header: {
                Text("Available Backends")
            } footer: {
                Text("Select a backend to use for AI generation")
            }
        }
        .navigationTitle("AI Backends")
        .sheet(isPresented: $showingSettings) {
            if let backend = settingsBackend {
                NavigationStack {
                    backend.settings.settingsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingSettings = false
                                }
                            }
                        }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await backendManager.initializeAllBackends()
        }
    }
    
    private func activeBackendCard(_ backend: AIBackend) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: backend.iconName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading) {
                    Text(backend.name)
                        .font(.headline)
                    Text("Currently Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            
            Text(backend.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func selectBackend(_ backend: AIBackend) async {
        do {
            try await backendManager.setActiveBackend(backend.id)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct BackendRow: View {
    let backend: AIBackend
    let isActive: Bool
    let onSelect: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: backend.iconName)
                        .foregroundStyle(isActive ? .blue : .secondary)
                    
                    Text(backend.name)
                        .font(.headline)
                    
                    if !backend.isAvailable {
                        Text("Unavailable")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(backend.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if backend.isAvailable {
                Button(action: onSelect) {
                    Text("Select")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
            }
            
            Button(action: onSettings) {
                Image(systemName: "gear")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Backend Info View

struct BackendInfoView: View {
    let backend: AIBackend
    @State private var models: [AIModel] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            Section {
                InfoRow(label: "Name", value: backend.name)
                InfoRow(label: "ID", value: backend.id)
                InfoRow(label: "Status", value: backend.isAvailable ? "Available" : "Unavailable")
            } header: {
                Text("Information")
            }
            
            Section {
                Text(backend.description)
                    .font(.body)
            } header: {
                Text("Description")
            }
            
            Section {
                if isLoading {
                    ProgressView()
                } else if models.isEmpty {
                    Text("No models available")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(models) { model in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.name)
                                .font(.headline)
                            if let description = model.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Models")
            }
        }
        .navigationTitle(backend.name)
        .task {
            await loadModels()
        }
    }
    
    private func loadModels() async {
        defer { isLoading = false }
        
        if backend.isAvailable {
            do {
                models = try await backend.listModels()
            } catch {
                print("Failed to load models: \(error)")
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    NavigationStack {
        BackendSelectionView()
    }
}
