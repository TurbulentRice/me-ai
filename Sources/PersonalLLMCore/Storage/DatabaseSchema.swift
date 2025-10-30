import Foundation
import SQLite

/// Database schema definitions for PersonalLLM storage
public enum DatabaseSchema {

    // MARK: - Tables

    public static let documents = Table("documents")
    public static let chunks = Table("chunks")

    // MARK: - Document Columns

    public static let docId = Expression<Int64>("id")
    public static let docFilename = Expression<String>("filename")
    public static let docMimeType = Expression<String>("mime_type")
    public static let docFileSize = Expression<Int64>("file_size")
    public static let docSourceURL = Expression<String?>("source_url")
    public static let docCreatedAt = Expression<Date>("created_at")
    public static let docLastModified = Expression<Date>("last_modified")
    public static let docChunkCount = Expression<Int>("chunk_count")

    // MARK: - Chunk Columns

    public static let chunkId = Expression<Int64>("id")
    public static let chunkDocId = Expression<Int64>("doc_id")
    public static let chunkText = Expression<String>("text")
    public static let chunkEmbedding = Expression<Data?>("embedding") // Stored as binary blob
    public static let chunkPosition = Expression<Int>("position")
    public static let chunkMeta = Expression<String>("meta") // JSON string
    public static let chunkCreatedAt = Expression<Date>("created_at")

    // MARK: - Schema Creation

    /// Creates all database tables with proper schema
    public static func createTables(db: Connection) throws {
        // Documents table
        try db.run(documents.create(ifNotExists: true) { t in
            t.column(docId, primaryKey: .autoincrement)
            t.column(docFilename)
            t.column(docMimeType)
            t.column(docFileSize)
            t.column(docSourceURL)
            t.column(docCreatedAt)
            t.column(docLastModified)
            t.column(docChunkCount, defaultValue: 0)
        })

        // Chunks table
        try db.run(chunks.create(ifNotExists: true) { t in
            t.column(chunkId, primaryKey: .autoincrement)
            t.column(chunkDocId)
            t.column(chunkText)
            t.column(chunkEmbedding)
            t.column(chunkPosition)
            t.column(chunkMeta)
            t.column(chunkCreatedAt)
            t.foreignKey(chunkDocId, references: documents, docId, delete: .cascade)
        })

        // Create index on doc_id for faster chunk queries
        try db.run(chunks.createIndex(chunkDocId, ifNotExists: true))

        // Create index on position for ordered retrieval
        try db.run(chunks.createIndex(chunkPosition, ifNotExists: true))
    }

    // MARK: - Helper Functions

    /// Converts embedding array to binary data for storage
    public static func embeddingToData(_ embedding: [Float]) -> Data {
        var data = Data(capacity: embedding.count * MemoryLayout<Float>.size)
        embedding.withUnsafeBytes { buffer in
            data.append(buffer.bindMemory(to: UInt8.self))
        }
        return data
    }

    /// Converts binary data back to embedding array
    public static func dataToEmbedding(_ data: Data) -> [Float] {
        let floatCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self).prefix(floatCount))
        }
    }

    /// Encodes ChunkMetadata to JSON string
    public static func encodeMetadata(_ meta: ChunkMetadata) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(meta)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw StorageError.invalidData
        }
        return jsonString
    }

    /// Decodes ChunkMetadata from JSON string
    public static func decodeMetadata(_ jsonString: String) throws -> ChunkMetadata {
        guard let data = jsonString.data(using: .utf8) else {
            throw StorageError.invalidData
        }
        let decoder = JSONDecoder()
        return try decoder.decode(ChunkMetadata.self, from: data)
    }
}
