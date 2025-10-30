import Foundation

/// Encrypted wrapper around VectorDatabase that encrypts sensitive document content
/// Note: Uses iOS Data Protection for database file encryption + CryptoKit for field-level encryption
public final class EncryptedVectorDatabase: VectorDatabase {
    private let innerDB: VectorDatabase
    private let encryption: DatabaseEncryption

    /// Initialize with an underlying database and encryption
    /// - Parameter database: The underlying vector database
    /// - Throws: EncryptionError if encryption setup fails
    public init(database: VectorDatabase) throws {
        self.innerDB = database
        self.encryption = try DatabaseEncryption()
    }

    /// Convenience initializer that creates an encrypted SQLite database
    /// - Parameter dbPath: Path to database file
    /// - Throws: Storage or encryption errors
    public convenience init(dbPath: URL) throws {
        // Ensure the database is in a protected location
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: dbPath.path
        )

        let db = try SQLiteVectorDB(dbPath: dbPath)
        try self.init(database: db)
    }

    // MARK: - VectorDatabase Protocol Implementation

    public func insertDocument(_ document: Document) throws -> Int64 {
        // Documents metadata is not encrypted (filenames, sizes are not sensitive)
        // Only chunk content will be encrypted
        return try innerDB.insertDocument(document)
    }

    public func insertChunks(_ chunks: [Chunk]) throws {
        // Encrypt chunk text before storage
        let encryptedChunks = try chunks.map { chunk -> Chunk in
            let encryptedText = try encryption.encrypt(chunk.text)

            return Chunk(
                id: chunk.id,
                docId: chunk.docId,
                text: encryptedText,
                embedding: chunk.embedding, // Embeddings don't need encryption (they're mathematical representations)
                position: chunk.position,
                meta: chunk.meta,
                createdAt: chunk.createdAt
            )
        }

        try innerDB.insertChunks(encryptedChunks)
    }

    public func searchSimilar(queryEmbedding: [Float], topK: Int) throws -> [SearchResult] {
        // Get encrypted results from database
        let encryptedResults = try innerDB.searchSimilar(queryEmbedding: queryEmbedding, topK: topK)

        // Decrypt chunk text in results
        return try encryptedResults.map { result -> SearchResult in
            let decryptedText = try encryption.decrypt(result.chunk.text)

            let decryptedChunk = Chunk(
                id: result.chunk.id,
                docId: result.chunk.docId,
                text: decryptedText,
                embedding: result.chunk.embedding,
                position: result.chunk.position,
                meta: result.chunk.meta,
                createdAt: result.chunk.createdAt
            )

            return SearchResult(
                chunk: decryptedChunk,
                score: result.score,
                document: result.document
            )
        }
    }

    public func deleteDocument(id: Int64) throws {
        try innerDB.deleteDocument(id: id)
    }

    public func getAllDocuments() throws -> [Document] {
        return try innerDB.getAllDocuments()
    }

    public func getDocument(id: Int64) throws -> Document? {
        return try innerDB.getDocument(id: id)
    }

    public func getChunks(forDocumentId docId: Int64) throws -> [Chunk] {
        let encryptedChunks = try innerDB.getChunks(forDocumentId: docId)

        // Decrypt chunk text
        return try encryptedChunks.map { chunk -> Chunk in
            let decryptedText = try encryption.decrypt(chunk.text)

            return Chunk(
                id: chunk.id,
                docId: chunk.docId,
                text: decryptedText,
                embedding: chunk.embedding,
                position: chunk.position,
                meta: chunk.meta,
                createdAt: chunk.createdAt
            )
        }
    }

    public func getDocumentCount() throws -> Int {
        return try innerDB.getDocumentCount()
    }

    public func getChunkCount() throws -> Int {
        return try innerDB.getChunkCount()
    }

    // MARK: - Security Operations

    /// Securely delete all data and encryption keys
    /// - Warning: This operation is irreversible
    public func secureDeleteAll() throws {
        // Delete all documents (cascades to chunks)
        let documents = try getAllDocuments()
        for document in documents {
            try deleteDocument(id: document.id)
        }

        // Delete encryption key from keychain
        try KeychainManager.shared.deleteDatabaseKey()
    }
}
