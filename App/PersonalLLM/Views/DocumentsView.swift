import SwiftUI
import UniformTypeIdentifiers
import PersonalLLMCore

struct DocumentsView: View {
    @StateObject var viewModel: DocumentsViewModel
    @State private var showingFilePicker = false
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        ZStack {
            if viewModel.documents.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                documentsList
            }

            // Loading overlay
            if viewModel.isLoading {
                ProgressView("Processing...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Add Documents", systemImage: "plus")
                    }

                    if !viewModel.documents.isEmpty {
                        Divider()

                        Button(role: .destructive) {
                            showingDeleteAllConfirmation = true
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.plainText, .pdf, .text],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .alert("Delete All Documents?", isPresented: $showingDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                viewModel.deleteAllDocuments()
            }
        } message: {
            Text("This will permanently delete all \(viewModel.documents.count) documents and their embeddings. This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Documents")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add documents to build your knowledge base")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingFilePicker = true
            } label: {
                Label("Add Documents", systemImage: "plus")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var documentsList: some View {
        List {
            Section {
                ForEach(viewModel.documents) { document in
                    DocumentRow(document: document)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteDocument(document)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("\(viewModel.documents.count) document\(viewModel.documents.count == 1 ? "" : "s")")
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard let urls = try? result.get() else { return }

        Task {
            await viewModel.ingestDocuments(urls)
        }
    }
}

struct DocumentRow: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Filename
            HStack {
                Image(systemName: iconForDocument(document))
                    .foregroundStyle(.blue)

                Text(document.filename)
                    .font(.headline)
                    .lineLimit(1)
            }

            // Metadata
            HStack(spacing: 12) {
                Label("\(document.chunkCount) chunks", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(formatFileSize(document.fileSize), systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatDate(document.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForDocument(_ document: Document) -> String {
        switch document.mimeType {
        case "application/pdf":
            return "doc.fill"
        case "text/markdown":
            return "doc.richtext"
        default:
            return "doc.text"
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationView {
        DocumentsView(viewModel: DocumentsViewModel(
            manager: DocumentManager(
                database: try! SQLiteVectorDB(dbPath: FileManager.default.temporaryDirectory.appendingPathComponent("preview.db")),
                ingestion: DocumentIngestion(
                    chunker: SemanticChunker(),
                    embedder: MockEmbedder(dimension: 384),
                    database: try! SQLiteVectorDB(dbPath: FileManager.default.temporaryDirectory.appendingPathComponent("preview.db"))
                )
            )
        ))
    }
}
