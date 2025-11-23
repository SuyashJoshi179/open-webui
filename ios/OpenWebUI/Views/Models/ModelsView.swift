//
//  ModelsView.swift
//  OpenWebUI
//
//  Model management view
//

import SwiftUI

struct ModelsView: View {
    @StateObject private var viewModel = ModelsViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Cloud Models") {
                    ForEach(viewModel.cloudModels) { model in
                        ModelRow(model: model)
                    }
                }
                
                Section("Local Models") {
                    ForEach(viewModel.localModels) { model in
                        LocalModelRow(localModel: model)
                    }
                    
                    Button(action: {}) {
                        Label("Download Model", systemImage: "arrow.down.circle")
                    }
                }
            }
            .navigationTitle("Models")
            .refreshable {
                await viewModel.loadModels()
            }
            .onAppear {
                Task {
                    await viewModel.loadModels()
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: Model
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.name)
                .font(.headline)
            
            if let description = model.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label(model.provider.rawValue.capitalized, systemImage: "server.rack")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LocalModelRow: View {
    let localModel: LocalModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localModel.name)
                    .font(.headline)
                
                Text(ByteCountFormatter.string(fromByteCount: localModel.size, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "iphone")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class ModelsViewModel: ObservableObject {
    @Published var cloudModels: [Model] = []
    @Published var localModels: [LocalModel] = []
    @Published var isLoading = false
    
    private let openAIService = OpenAIService.shared
    private let mlxService = MLXService.shared
    
    func loadModels() async {
        isLoading = true
        
        // Load cloud models
        do {
            cloudModels = try await openAIService.listModels()
        } catch {
            print("Error loading cloud models: \(error)")
        }
        
        // Load local models
        localModels = mlxService.listLocalModels()
        
        isLoading = false
    }
}

#Preview {
    ModelsView()
}
