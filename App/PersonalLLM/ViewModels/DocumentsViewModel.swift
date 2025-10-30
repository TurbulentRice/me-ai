import Foundation
import Combine
import PersonalLLMCore

/// View model for documents management
@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published var documents: [Document] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let manager: DocumentManager

    init(manager: DocumentManager) {
        self.manager = manager
        loadDocuments()
    }

    /// Load all documents
    func loadDocuments() {
        isLoading = true
        errorMessage = nil

        do {
            documents = try manager.getAllDocuments()
        } catch {
            errorMessage = "Failed to load documents: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Ingest documents from URLs
    func ingestDocuments(_ urls: [URL]) async {
        isLoading = true
        errorMessage = nil

        var successCount = 0
        var failureCount = 0

        for url in urls {
            // Start accessing security-scoped resource
            let hasAccess = url.startAccessingSecurityScopedResource()

            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                _ = try await manager.ingestDocument(fileURL: url)
                successCount += 1
            } catch {
                failureCount += 1
                print("Failed to ingest \(url.lastPathComponent): \(error)")
            }
        }

        // Reload documents
        loadDocuments()

        // Show result message
        if failureCount > 0 {
            errorMessage = "Ingested \(successCount) document(s), failed \(failureCount)"
        }

        isLoading = false
    }

    /// Delete a document
    func deleteDocument(_ document: Document) {
        do {
            try manager.deleteDocument(id: document.id)
            loadDocuments()
        } catch {
            errorMessage = "Failed to delete document: \(error.localizedDescription)"
        }
    }

    /// Delete all documents
    func deleteAllDocuments() {
        do {
            try manager.deleteAllDocuments()
            loadDocuments()
        } catch {
            errorMessage = "Failed to delete all documents: \(error.localizedDescription)"
        }
    }

    /// Get document count
    func getDocumentCount() -> Int {
        documents.count
    }

    /// Get total database size (formatted)
    func getFormattedDatabaseSize() -> String {
        do {
            let size = try manager.getDatabaseSize()
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } catch {
            return "Unknown"
        }
    }
}
