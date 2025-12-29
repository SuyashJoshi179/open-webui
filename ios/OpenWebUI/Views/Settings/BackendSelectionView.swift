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
    @State private var settingsBackend: (any AIBackend)?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            Section {
                ForEach(backendManager.backends, id: \.id) { backend in
                    BackendRowWithModels(
                        backend: backend,
                        onAddModel: {
                            settingsBackend = backend
                            showingSettings = true
                        },
                        backendManager: backendManager
                    )
                }
            } header: {
                Text("Backends")
            } footer: {
                Text("Add models to backends to make them available for chat")
            }
        }
        .navigationTitle("AI Backends")
        .sheet(isPresented: $showingSettings) {
            if let backend = settingsBackend {
                NavigationStack {
                    AddModelView(backend: backend, onDismiss: {
                        showingSettings = false
                        backendManager.refreshModels()
                    })
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    

}

// MARK: - Backend Row with Models

struct BackendRowWithModels: View {
    let backend: any AIBackend
    let onAddModel: () -> Void
    @ObservedObject var backendManager: BackendManager
    @State private var isExpanded = false
    
    private var models: [ConfiguredAIModel] {
        backend.getConfiguredModels()
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if models.isEmpty {
                HStack {
                    Text("No models configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(models) { model in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.subheadline)
                        Text(model.modelIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            
            if backend.supportsModelAddition() {
                Button(action: onAddModel) {
                    Label("Add Model", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
        } label: {
            HStack {
                Image(systemName: backend.iconName)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(backend.name)
                        .font(.headline)
                    Text(backend.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("\(models.count) model\(models.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Model View

struct AddModelView: View {
    let backend: any AIBackend
    let onDismiss: () -> Void
    
    @State private var displayName = ""
    @State private var modelIdentifier = ""
    @State private var apiURL = ""
    @State private var apiKey = ""
    @State private var organizationId = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section("Model Information") {
                TextField("Display Name", text: $displayName)
                    .textContentType(.name)
                TextField("Model ID", text: $modelIdentifier)
                    .textContentType(.none)
                    .autocapitalization(.none)
            }
            
            if backend.id == "openai-compatible" {
                Section("API Configuration") {
                    TextField("API URL", text: $apiURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                    
                    TextField("Organization ID (Optional)", text: $organizationId)
                        .textContentType(.none)
                        .autocapitalization(.none)
                }
            }
            
            Section {
                Text(backend.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onDismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addModel()
                }
                .disabled(!isValid)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isValid: Bool {
        !displayName.isEmpty && !modelIdentifier.isEmpty &&
        (backend.id != "openai-compatible" || !apiURL.isEmpty)
    }
    
    private func addModel() {
        var config = ModelConfiguration()
        config.displayName = displayName
        config.modelIdentifier = modelIdentifier
        
        if backend.id == "openai-compatible" {
            config.apiURL = apiURL
            config.apiKey = apiKey.isEmpty ? nil : apiKey
            config.organizationId = organizationId.isEmpty ? nil : organizationId
        }
        
        do {
            _ = try backend.addModel(config)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationStack {
        BackendSelectionView()
    }
}
