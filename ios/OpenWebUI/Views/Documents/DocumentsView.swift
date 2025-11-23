//
//  DocumentsView.swift
//  OpenWebUI
//
//  Document management for RAG
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @StateObject private var viewModel = DocumentsViewModel()
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.documents.isEmpty {
                    emptyState
                } else {
                    documentsList
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingFilePicker = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .onAppear {
                Task {
                    await viewModel.loadDocuments()
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No documents")
                .font(.headline)
            
            Text("Upload documents for RAG")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: { showingFilePicker = true }) {
                Label("Upload Document", systemImage: "arrow.up.doc")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var documentsList: some View {
        List {
            ForEach(viewModel.documents) { document in
                DocumentRow(document: document)
            }
            .onDelete { indexSet in
                Task {
                    await viewModel.deleteDocuments(at: indexSet)
                }
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.uploadDocument(url: url)
            }
        case .failure(let error):
            print("Error selecting file: \(error)")
        }
    }
}

struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        HStack {
            Image(systemName: iconForDocumentType(document.type))
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.headline)
                
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: document.size, countStyle: .file))
                    Text("•")
                    Text(document.uploadedAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForDocumentType(_ type: String) -> String {
        switch type.lowercased() {
        case "pdf": return "doc.fill"
        case "txt", "text": return "doc.text"
        case "md", "markdown": return "note.text"
        default: return "doc"
        }
    }
}

@MainActor
class DocumentsViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let ragService = RAGService.shared
    
    func loadDocuments() async {
        isLoading = true
        
        do {
            documents = try await ragService.listDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func uploadDocument(url: URL) async {
        do {
            // Start accessing security-scoped resource
            let _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            
            let document = try await ragService.uploadDocument(fileURL: url)
            documents.insert(document, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteDocuments(at offsets: IndexSet) async {
        for index in offsets {
            let document = documents[index]
            do {
                try await ragService.deleteDocument(id: document.id)
                documents.remove(at: index)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    DocumentsView()
}
