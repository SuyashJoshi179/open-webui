//
//  ModelPickerView.swift
//  OpenWebUI
//
//  A simple picker for selecting the active AI model in chat
//

import SwiftUI

struct ModelPickerView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var backendManager = BackendManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                if backendManager.allModels.isEmpty {
                    ContentUnavailableView(
                        "No Models Available",
                        systemImage: "cube.transparent",
                        description: Text("Add models in Backend Settings")
                    )
                } else {
                    ForEach(groupedModels, id: \.backend.id) { group in
                        Section(header: backendHeader(group.backend)) {
                            ForEach(group.models) { model in
                                modelRow(model)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                // Ensure we have the latest state
                backendManager.refreshModels()
            }
        }
    }
    
    private var groupedModels: [(backend: any AIBackend, models: [ConfiguredAIModel])] {
        backendManager.getModelsGroupedByBackend()
    }
    
    private func backendHeader(_ backend: any AIBackend) -> some View {
        HStack {
            Image(systemName: backend.iconName)
                .foregroundStyle(.blue)
            Text(backend.name)
        }
    }
    
    private func modelRow(_ model: ConfiguredAIModel) -> some View {
        Button(action: {
            backendManager.selectModel(model)
            isPresented = false
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(model.modelIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if backendManager.activeModel?.id == model.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ModelPickerView(isPresented: .constant(true))
}
