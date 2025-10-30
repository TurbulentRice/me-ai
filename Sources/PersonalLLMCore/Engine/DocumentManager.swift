import Foundation

/// Manager for document-related operations
public final class DocumentManager: Sendable {
    private let database: VectorDatabase
    private let ingestion: DocumentIngestion

    public init(database: VectorDatabase, ingestion: DocumentIngestion) {
        self.database = database
        self.ingestion = ingestion
    }

    // MARK: - Document Operations

    /// Get all documents
    public func getAllDocuments() throws -> [Document] {
        try database.getAllDocuments()
    }

    /// Delete a document and its chunks
    public func deleteDocument(id: Int64) throws {
        try database.deleteDocument(id: id)
    }

    /// Get document count
    public func getDocumentCount() throws -> Int {
        try database.getDocumentCount()
    }

    /// Get total database size
    public func getDatabaseSize() throws -> Int64 {
        // This would need to be implemented in VectorDatabase protocol
        // For now, return a placeholder
        return 0
    }

    /// Ingest a document from URL
    public func ingestDocument(fileURL: URL) async throws -> Document {
        try await ingestion.ingest(fileURL: fileURL)
    }

    /// Ingest text directly
    public func ingestText(_ text: String, filename: String) async throws -> Document {
        try await ingestion.ingestText(text, filename: filename)
    }

    /// Delete all documents
    public func deleteAllDocuments() throws {
        let docs = try getAllDocuments()
        for doc in docs {
            try deleteDocument(id: doc.id)
        }
    }
}
