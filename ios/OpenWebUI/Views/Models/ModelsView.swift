//
//  ModelsView.swift
//  OpenWebUI
//
//  Model management view
//

import SwiftUI

struct ModelsView: View {
    @ObservedObject private var backendManager = BackendManager.shared
    @State private var showingBackendSettings = false
    
    var body: some View {
        NavigationStack {
            modelsList
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingBackendSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingBackendSettings) {
                NavigationStack {
                    BackendSelectionView()
                }
            }
            .refreshable {
                backendManager.refreshModels()
            }
        }
    }
    
    private var modelsList: some View {
        List {
            if backendManager.allModels.isEmpty {
                Section {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Models Available")
                            .font(.headline)
                        Text("Add models from backends in Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingBackendSettings = true }) {
                            Label("Manage Backends", systemImage: "gearshape")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(backendManager.allModels) { model in
                    ModelRowWithBackend(model: model, backendManager: backendManager)
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: ConfiguredAIModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.displayName)
                .font(.headline)
            
            Text(model.modelIdentifier)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Label("\(model.capabilities.maxContextLength) tokens", systemImage: "text.word.spacing")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ModelRowWithBackend: View {
    let model: ConfiguredAIModel
    let backendManager: BackendManager
    
    var body: some View {
        Button(action: {
            backendManager.selectModel(model)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if backendManager.activeModel?.id == model.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    
                    Text(model.modelIdentifier)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        if let backend = backendManager.getBackend(id: model.backendId) {
                            Label(backend.name, systemImage: backend.iconName)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        
                        Label("\(model.capabilities.maxContextLength) tokens", systemImage: "text.word.spacing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ModelsView()
}
