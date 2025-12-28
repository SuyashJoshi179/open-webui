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
                if !viewModel.localModels.isEmpty {
                    Section("On-Device Models") {
                        ForEach(viewModel.localModels) { model in
                            LocalModelRow(localModel: model)
                        }
                    }
                }
                
                if !viewModel.cloudModels.isEmpty {
                    Section("Cloud Models") {
                        ForEach(viewModel.cloudModels) { model in
                            ModelRow(model: model)
                        }
                    }
                } else if viewModel.externalAPIURL.isEmpty {
                    Section {
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "cloud.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Cloud Models")
                                .font(.headline)
                            Text("Configure an external API in Settings to use cloud models")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
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
    
    @AppStorage("externalAPIURL") var externalAPIURL = ""
    @AppStorage("externalAPIKey") private var externalAPIKey = ""
    
    private let openAIService = OpenAIService.shared
    
    func loadModels() async {
        isLoading = true
        
        // Always load local Apple Intelligence model first
        if #available(iOS 26.0, *) {
            let mlxService = MLXService.shared
            localModels = mlxService.listLocalModels()
        }
        
        // Only load cloud models if user has configured an external API
        if !externalAPIURL.isEmpty && !externalAPIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                cloudModels = try await openAIService.listModels()
            } catch {
                print("Error loading cloud models: \(error)")
                cloudModels = []
            }
        } else {
            // No external API configured, clear cloud models
            cloudModels = []
        }
        
        isLoading = false
    }
}

#Preview {
    ModelsView()
}
