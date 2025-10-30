# API Reference

**Version**: 0.1.0
**Module**: PersonalLLMCore
**Platform**: iOS 17+, macOS 14+

## Overview

PersonalLLMCore provides the core functionality for the Personal AI application, including storage, RAG engine, model runtime, and privacy features.

## Core Modules

### Storage

#### `VectorDatabase` Protocol

Main interface for document and vector storage operations.

```swift
public protocol VectorDatabase: Sendable {
    func insertDocument(_ document: Document) throws -> Int64
    func insertChunks(_ chunks: [Chunk]) throws
    func searchSimilar(queryEmbedding: [Float], topK: Int) throws -> [SearchResult]
    func deleteDocument(id: Int64) throws
    func getAllDocuments() throws -> [Document]
    func getDocument(id: Int64) throws -> Document?
    func getChunks(forDocumentId docId: Int64) throws -> [Chunk]
    func getDocumentCount() throws -> Int
    func getChunkCount() throws -> Int
}
```

**Implementations**: `SQLiteVectorDB`, `EncryptedVectorDatabase`

#### Key Types

```swift
public struct Document {
    let id: Int64
    let filename: String
    let mimeType: String
    let fileSize: Int64
    let sourceURL: URL?
    let createdAt: Date
    let lastModified: Date
    var chunkCount: Int
}

public struct Chunk {
    let id: Int64
    let docId: Int64
    let text: String
    let embedding: [Float]?
    let position: Int
    let meta: ChunkMetadata
    let createdAt: Date
}

public struct SearchResult {
    let chunk: Chunk
    let score: Float
    let document: Document
}
```

### Model Runtime

#### `LocalLLM` Protocol

```swift
public protocol LocalLLM: Sendable {
    func load(modelPath: URL, config: LLMConfig) async throws
    func generate(
        prompt: String,
        stopSequences: [String],
        maxTokens: Int,
        temperature: Float
    ) async throws -> AsyncStream<String>
    func unload() throws
    var isLoaded: Bool { get }
    var modelInfo: ModelInfo? { get }
}
```

**Implementations**: `MockLLM` (for testing)

#### `Embedder` Protocol

```swift
public protocol Embedder: Sendable {
    func embed(text: String) async throws -> [Float]
    func embed(texts: [String]) async throws -> [[Float]]
    var embeddingDimension: Int { get }
}
```

**Implementations**: `MockEmbedder`, `LocalEmbedder`

### RAG Engine

#### `RAGEngine`

Main engine for retrieval-augmented generation.

```swift
public final class RAGEngine: Sendable {
    public init(
        embedder: Embedder,
        database: VectorDatabase,
        llm: LocalLLM,
        config: RAGConfig = .default
    )

    public func answer(
        query: String,
        topK: Int = 5,
        systemPrompt: String? = nil
    ) async throws -> (stream: AsyncStream<String>, citations: [Citation])

    public func answerComplete(
        query: String,
        topK: Int = 5
    ) async throws -> RAGResponse
}
```

#### Citation Tracking

```swift
public struct Citation {
    let documentName: String
    let chunkText: String
    let score: Float
}

public struct RAGResponse {
    let answer: String
    let citations: [Citation]
    let tokensGenerated: Int
    let processingTime: TimeInterval
}
```

### Document Management

#### `DocumentManager`

High-level document management interface.

```swift
public final class DocumentManager {
    public init(database: VectorDatabase, ingestion: DocumentIngestion)

    public func ingestDocument(fileURL: URL) async throws -> Document
    public func ingestText(_ text: String, filename: String) async throws -> Document
    public func deleteDocument(id: Int64) throws
    public func deleteAllDocuments() throws
    public func getAllDocuments() throws -> [Document]
}
```

#### `DocumentIngestion`

Document processing and chunking pipeline.

```swift
public final class DocumentIngestion {
    public init(
        chunker: TextChunker,
        embedder: Embedder,
        database: VectorDatabase
    )

    public func ingest(fileURL: URL) async throws -> Document
    public func ingestText(_ text: String, filename: String) async throws -> Document
}
```

### Privacy & Security

#### `EncryptedVectorDatabase`

Encrypted wrapper for vector database.

```swift
public final class EncryptedVectorDatabase: VectorDatabase {
    public init(database: VectorDatabase) throws
    public convenience init(dbPath: URL) throws

    // Implements all VectorDatabase methods with transparent encryption

    public func secureDeleteAll() throws
}
```

#### `KeychainManager`

Secure key management.

```swift
public final class KeychainManager {
    public static let shared: KeychainManager

    public func getOrCreateDatabaseKey() throws -> String
    public func deleteDatabaseKey() throws
}
```

#### `DatabaseEncryption`

Field-level encryption using AES-GCM.

```swift
public final class DatabaseEncryption: Sendable {
    public init() throws

    public func encrypt(_ plaintext: String) throws -> String
    public func decrypt(_ ciphertext: String) throws -> String
    public func encryptData(_ data: Data) throws -> Data
    public func decryptData(_ encryptedData: Data) throws -> Data
}
```

#### `PrivacyManager`

Centralized privacy controls.

```swift
public final class PrivacyManager {
    public static let shared: PrivacyManager

    public var isOfflineModeEnabled: Bool { get set }
    public var isEncryptionEnabled: Bool { get }

    public func deleteAllData(database: VectorDatabase) throws
    public func deleteDatabaseFile(at path: URL) throws
    public func generatePrivacyReport(
        database: VectorDatabase,
        dbPath: URL
    ) throws -> PrivacyReport
}
```

### UI Layer

#### `SettingsViewModel`

SwiftUI-compatible settings view model.

```swift
@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var offlineMode: Bool
    @Published public var documentCount: Int
    @Published public var chunkCount: Int
    @Published public var databaseSize: String
    @Published public var encryptionEnabled: Bool

    public init(database: VectorDatabase, dbPath: URL)

    public func loadSettings() async
    public func deleteAllData()
    public func resetDatabase()
}
```

## Configuration

### `LLMConfig`

```swift
public struct LLMConfig: Sendable {
    public let contextLength: Int
    public let batchSize: Int
    public let temperature: Float
    public let topP: Float
    public let topK: Int

    public static let `default`: LLMConfig
}
```

### `RAGConfig`

```swift
public struct RAGConfig: Sendable {
    public let defaultSystemPrompt: String
    public let stopSequences: [String]
    public let maxResponseTokens: Int
    public let temperature: Float

    public static let `default`: RAGConfig
}
```

## Error Types

```swift
public enum StorageError: LocalizedError {
    case insertFailed(String)
    case deleteFailed(String)
    case notFound(String)
    case invalidData(String)
}

public enum EncryptionError: LocalizedError {
    case invalidKey
    case invalidInput
    case encryptionFailed
    case decryptionFailed
}

public enum KeychainError: LocalizedError {
    case unableToStore(OSStatus)
    case unableToRetrieve(OSStatus)
    case unableToDelete(OSStatus)
    case invalidKeyData
}

public enum RAGError: Error {
    case embeddingFailed
    case noResults
    case modelNotLoaded
}
```

## Usage Examples

### Basic RAG Query

```swift
// Initialize components
let database = try SQLiteVectorDB(dbPath: dbPath)
let embedder = MockEmbedder(dimension: 384)
let llm = MockLLM(delay: .milliseconds(10))

// Load model
try await llm.load(modelPath: modelURL, config: .default)

// Create RAG engine
let ragEngine = RAGEngine(
    embedder: embedder,
    database: database,
    llm: llm
)

// Query
let (stream, citations) = try await ragEngine.answer(query: "What is Swift?")

// Consume streaming response
for await token in stream {
    print(token, terminator: "")
}

// Check citations
for citation in citations {
    print("Source: \(citation.documentName)")
}
```

### Document Ingestion

```swift
let documentManager = DocumentManager(
    database: database,
    ingestion: DocumentIngestion(
        chunker: SemanticChunker(),
        embedder: embedder,
        database: database
    )
)

// Ingest text
let document = try await documentManager.ingestText(
    "Swift is a powerful programming language.",
    filename: "swift_intro.txt"
)

print("Created \(document.chunkCount) chunks")
```

### Encrypted Storage

```swift
// Use encrypted database
let encryptedDB = try EncryptedVectorDatabase(dbPath: dbPath)

// All operations transparently encrypted
let docId = try encryptedDB.insertDocument(document)
try encryptedDB.insertChunks(chunks)

// Search works normally (embeddings not encrypted)
let results = try encryptedDB.searchSimilar(
    queryEmbedding: embedding,
    topK: 5
)
```

## Thread Safety

- All core protocols conform to `Sendable`
- Database operations are thread-safe via SQLite serialization
- `@MainActor` used for UI components
- Async/await throughout for clean concurrency

## Performance Notes

- Vector search: O(n) brute-force (suitable for <10K chunks)
- Encryption overhead: ~5-7%
- Embedding: ~10-15ms per text (mock)
- LLM generation: ~2ms per token (mock)

See [PERFORMANCE.md](PERFORMANCE.md) for detailed benchmarks.

## Further Reading

- [PROTOTYPE.md](PROTOTYPE.md) - Architecture overview
- [PHASE_*_COMPLETION.md](.) - Implementation details
- [VSCODE_WORKFLOW.md](VSCODE_WORKFLOW.md) - Development guide
