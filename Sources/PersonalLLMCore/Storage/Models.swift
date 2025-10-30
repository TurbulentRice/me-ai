import Foundation

// MARK: - Document

/// Represents an ingested document in the knowledge base
public struct Document: Codable, Identifiable, Sendable {
    public let id: Int64
    public let filename: String
    public let mimeType: String
    public let fileSize: Int64
    public let sourceURL: URL?
    public let createdAt: Date
    public let lastModified: Date
    public var chunkCount: Int

    public init(
        id: Int64,
        filename: String,
        mimeType: String,
        fileSize: Int64,
        sourceURL: URL?,
        createdAt: Date,
        lastModified: Date,
        chunkCount: Int
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.chunkCount = chunkCount
    }
}

// MARK: - Chunk

/// Represents a chunk of text with its vector embedding
public struct Chunk: Codable, Identifiable, Sendable {
    public let id: Int64
    public let docId: Int64
    public let text: String
    public let embedding: [Float]?
    public let position: Int
    public let meta: ChunkMetadata
    public let createdAt: Date

    public init(
        id: Int64,
        docId: Int64,
        text: String,
        embedding: [Float]?,
        position: Int,
        meta: ChunkMetadata,
        createdAt: Date
    ) {
        self.id = id
        self.docId = docId
        self.text = text
        self.embedding = embedding
        self.position = position
        self.meta = meta
        self.createdAt = createdAt
    }
}

// MARK: - ChunkMetadata

/// Metadata for a text chunk
public struct ChunkMetadata: Codable, Sendable {
    public let startOffset: Int
    public let endOffset: Int
    public let tokenCount: Int
    public let pageNumber: Int?

    public init(
        startOffset: Int,
        endOffset: Int,
        tokenCount: Int,
        pageNumber: Int? = nil
    ) {
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.tokenCount = tokenCount
        self.pageNumber = pageNumber
    }
}

// MARK: - SearchResult

/// Result from a vector similarity search
public struct SearchResult: Sendable {
    public let chunk: Chunk
    public let score: Float
    public let document: Document

    public init(chunk: Chunk, score: Float, document: Document) {
        self.chunk = chunk
        self.score = score
        self.document = document
    }
}

// MARK: - Storage Errors

/// Errors that can occur during storage operations
public enum StorageError: Error, LocalizedError {
    case databaseNotFound
    case invalidData
    case insertFailed(String)
    case queryFailed(String)
    case deleteFailed(String)
    case notFound(String)
    case corruptedData

    public var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Database file not found"
        case .invalidData:
            return "Invalid data format"
        case .insertFailed(let message):
            return "Insert operation failed: \(message)"
        case .queryFailed(let message):
            return "Query operation failed: \(message)"
        case .deleteFailed(let message):
            return "Delete operation failed: \(message)"
        case .notFound(let item):
            return "\(item) not found"
        case .corruptedData:
            return "Database data is corrupted"
        }
    }
}
