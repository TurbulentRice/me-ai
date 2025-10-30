import Foundation
@preconcurrency import SQLite

// MARK: - VectorDatabase Protocol

/// Protocol for vector database operations
public protocol VectorDatabase: Sendable {
    /// Insert a document into the database
    func insertDocument(_ document: Document) throws -> Int64

    /// Insert multiple chunks for a document
    func insertChunks(_ chunks: [Chunk]) throws

    /// Search for similar chunks using vector similarity
    func searchSimilar(queryEmbedding: [Float], topK: Int) throws -> [SearchResult]

    /// Delete a document and all its chunks
    func deleteDocument(id: Int64) throws

    /// Retrieve all documents
    func getAllDocuments() throws -> [Document]

    /// Retrieve a specific document by ID
    func getDocument(id: Int64) throws -> Document?

    /// Retrieve all chunks for a document
    func getChunks(forDocumentId docId: Int64) throws -> [Chunk]

    /// Get total document count
    func getDocumentCount() throws -> Int

    /// Get total chunk count
    func getChunkCount() throws -> Int
}

// MARK: - SQLiteVectorDB Implementation

/// SQLite-based vector database with cosine similarity search
public final class SQLiteVectorDB: VectorDatabase {
    private let db: Connection
    private let dbPath: URL

    /// Initialize with database file path
    public init(dbPath: URL) throws {
        self.dbPath = dbPath

        // Ensure parent directory exists
        let parentDir = dbPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Connect to database
        self.db = try Connection(dbPath.path)

        // Enable foreign key constraints (required for cascade delete)
        try db.execute("PRAGMA foreign_keys = ON")

        // Create tables if they don't exist
        try DatabaseSchema.createTables(db: db)
    }

    // MARK: - Document Operations

    public func insertDocument(_ document: Document) throws -> Int64 {
        let insert = DatabaseSchema.documents.insert(
            DatabaseSchema.docFilename <- document.filename,
            DatabaseSchema.docMimeType <- document.mimeType,
            DatabaseSchema.docFileSize <- document.fileSize,
            DatabaseSchema.docSourceURL <- document.sourceURL?.absoluteString,
            DatabaseSchema.docCreatedAt <- document.createdAt,
            DatabaseSchema.docLastModified <- document.lastModified,
            DatabaseSchema.docChunkCount <- document.chunkCount
        )

        do {
            return try db.run(insert)
        } catch {
            throw StorageError.insertFailed("Failed to insert document: \(error.localizedDescription)")
        }
    }

    public func getDocument(id: Int64) throws -> Document? {
        let query = DatabaseSchema.documents.filter(DatabaseSchema.docId == id)

        guard let row = try db.pluck(query) else {
            return nil
        }

        return try documentFromRow(row)
    }

    public func getAllDocuments() throws -> [Document] {
        let query = DatabaseSchema.documents.order(DatabaseSchema.docCreatedAt.desc)
        var documents: [Document] = []

        for row in try db.prepare(query) {
            documents.append(try documentFromRow(row))
        }

        return documents
    }

    public func deleteDocument(id: Int64) throws {
        let document = DatabaseSchema.documents.filter(DatabaseSchema.docId == id)

        do {
            let deleted = try db.run(document.delete())
            if deleted == 0 {
                throw StorageError.notFound("Document with id \(id)")
            }
        } catch {
            throw StorageError.deleteFailed("Failed to delete document: \(error.localizedDescription)")
        }
    }

    public func getDocumentCount() throws -> Int {
        return try db.scalar(DatabaseSchema.documents.count)
    }

    // MARK: - Chunk Operations

    public func insertChunks(_ chunks: [Chunk]) throws {
        do {
            try db.transaction {
                for chunk in chunks {
                    let embeddingData = chunk.embedding.map { DatabaseSchema.embeddingToData($0) }
                    let metaJSON = try DatabaseSchema.encodeMetadata(chunk.meta)

                    let insert = DatabaseSchema.chunks.insert(
                        DatabaseSchema.chunkDocId <- chunk.docId,
                        DatabaseSchema.chunkText <- chunk.text,
                        DatabaseSchema.chunkEmbedding <- embeddingData,
                        DatabaseSchema.chunkPosition <- chunk.position,
                        DatabaseSchema.chunkMeta <- metaJSON,
                        DatabaseSchema.chunkCreatedAt <- chunk.createdAt
                    )

                    _ = try db.run(insert)
                }
            }
        } catch {
            throw StorageError.insertFailed("Failed to insert chunks: \(error.localizedDescription)")
        }
    }

    public func getChunks(forDocumentId docId: Int64) throws -> [Chunk] {
        let query = DatabaseSchema.chunks
            .filter(DatabaseSchema.chunkDocId == docId)
            .order(DatabaseSchema.chunkPosition.asc)

        var chunks: [Chunk] = []

        for row in try db.prepare(query) {
            chunks.append(try chunkFromRow(row))
        }

        return chunks
    }

    public func getChunkCount() throws -> Int {
        return try db.scalar(DatabaseSchema.chunks.count)
    }

    // MARK: - Vector Search

    public func searchSimilar(queryEmbedding: [Float], topK: Int) throws -> [SearchResult] {
        // Fetch all chunks with embeddings
        let query = DatabaseSchema.chunks.filter(DatabaseSchema.chunkEmbedding != nil)

        var results: [(chunk: Chunk, score: Float)] = []

        for row in try db.prepare(query) {
            let chunk = try chunkFromRow(row)

            guard let embedding = chunk.embedding else { continue }

            let similarity = cosineSimilarity(queryEmbedding, embedding)
            results.append((chunk, similarity))
        }

        // Sort by similarity (highest first) and take topK
        results.sort { $0.score > $1.score }
        let topResults = Array(results.prefix(topK))

        // Fetch corresponding documents
        var searchResults: [SearchResult] = []

        for (chunk, score) in topResults {
            guard let document = try getDocument(id: chunk.docId) else {
                continue
            }

            searchResults.append(SearchResult(chunk: chunk, score: score, document: document))
        }

        return searchResults
    }

    // MARK: - Helper Functions

    private func documentFromRow(_ row: Row) throws -> Document {
        let sourceURLString = row[DatabaseSchema.docSourceURL]
        let sourceURL = sourceURLString.flatMap { URL(string: $0) }

        return Document(
            id: row[DatabaseSchema.docId],
            filename: row[DatabaseSchema.docFilename],
            mimeType: row[DatabaseSchema.docMimeType],
            fileSize: row[DatabaseSchema.docFileSize],
            sourceURL: sourceURL,
            createdAt: row[DatabaseSchema.docCreatedAt],
            lastModified: row[DatabaseSchema.docLastModified],
            chunkCount: row[DatabaseSchema.docChunkCount]
        )
    }

    private func chunkFromRow(_ row: Row) throws -> Chunk {
        let embeddingData = row[DatabaseSchema.chunkEmbedding]
        let embedding = embeddingData.map { DatabaseSchema.dataToEmbedding($0) }

        let metaJSON = row[DatabaseSchema.chunkMeta]
        let meta = try DatabaseSchema.decodeMetadata(metaJSON)

        return Chunk(
            id: row[DatabaseSchema.chunkId],
            docId: row[DatabaseSchema.chunkDocId],
            text: row[DatabaseSchema.chunkText],
            embedding: embedding,
            position: row[DatabaseSchema.chunkPosition],
            meta: meta,
            createdAt: row[DatabaseSchema.chunkCreatedAt]
        )
    }

    /// Calculate cosine similarity between two vectors
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }
}
