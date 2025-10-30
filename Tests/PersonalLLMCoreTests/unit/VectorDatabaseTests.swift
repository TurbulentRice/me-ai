import XCTest
@testable import PersonalLLMCore

final class VectorDatabaseTests: XCTestCase {
    var db: SQLiteVectorDB!
    var tempDBPath: URL!

    override func setUp() async throws {
        // Create temporary database for each test
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")

        db = try SQLiteVectorDB(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        // Clean up temporary database
        try? FileManager.default.removeItem(at: tempDBPath)
        db = nil
        tempDBPath = nil
    }

    // MARK: - Document Tests

    func testInsertAndRetrieveDocument() throws {
        // Create test document
        let document = Document(
            id: 0, // Will be auto-generated
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 1024,
            sourceURL: URL(string: "file:///test.txt"),
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 0
        )

        // Insert document
        let docId = try db.insertDocument(document)
        XCTAssertGreaterThan(docId, 0, "Document ID should be positive")

        // Retrieve document
        let retrieved = try db.getDocument(id: docId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.filename, "test.txt")
        XCTAssertEqual(retrieved?.mimeType, "text/plain")
        XCTAssertEqual(retrieved?.fileSize, 1024)
    }

    func testGetAllDocuments() throws {
        // Insert multiple documents
        for i in 1...5 {
            let doc = Document(
                id: 0,
                filename: "test\(i).txt",
                mimeType: "text/plain",
                fileSize: Int64(i * 100),
                sourceURL: nil,
                createdAt: Date(),
                lastModified: Date(),
                chunkCount: 0
            )
            _ = try db.insertDocument(doc)
        }

        // Retrieve all documents
        let documents = try db.getAllDocuments()
        XCTAssertEqual(documents.count, 5)

        // Verify order (should be descending by creation date)
        XCTAssertTrue(documents[0].createdAt >= documents[1].createdAt)
    }

    func testDeleteDocument() throws {
        // Insert document
        let document = Document(
            id: 0,
            filename: "to_delete.txt",
            mimeType: "text/plain",
            fileSize: 500,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 0
        )
        let docId = try db.insertDocument(document)

        // Delete document
        try db.deleteDocument(id: docId)

        // Verify deletion
        let retrieved = try db.getDocument(id: docId)
        XCTAssertNil(retrieved, "Document should be deleted")
    }

    func testDocumentCount() throws {
        XCTAssertEqual(try db.getDocumentCount(), 0)

        // Insert documents
        for i in 1...3 {
            let doc = Document(
                id: 0,
                filename: "doc\(i).txt",
                mimeType: "text/plain",
                fileSize: 100,
                sourceURL: nil,
                createdAt: Date(),
                lastModified: Date(),
                chunkCount: 0
            )
            _ = try db.insertDocument(doc)
        }

        XCTAssertEqual(try db.getDocumentCount(), 3)
    }

    // MARK: - Chunk Tests

    func testInsertAndRetrieveChunks() throws {
        // Insert document first
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 1000,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 2
        )
        let docId = try db.insertDocument(document)

        // Create test chunks
        let chunks = [
            Chunk(
                id: 0,
                docId: docId,
                text: "This is the first chunk.",
                embedding: [0.1, 0.2, 0.3],
                position: 0,
                meta: ChunkMetadata(startOffset: 0, endOffset: 24, tokenCount: 5),
                createdAt: Date()
            ),
            Chunk(
                id: 0,
                docId: docId,
                text: "This is the second chunk.",
                embedding: [0.4, 0.5, 0.6],
                position: 1,
                meta: ChunkMetadata(startOffset: 25, endOffset: 50, tokenCount: 5),
                createdAt: Date()
            )
        ]

        // Insert chunks
        try db.insertChunks(chunks)

        // Retrieve chunks
        let retrieved = try db.getChunks(forDocumentId: docId)
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved[0].text, "This is the first chunk.")
        XCTAssertEqual(retrieved[1].text, "This is the second chunk.")
        XCTAssertEqual(retrieved[0].position, 0)
        XCTAssertEqual(retrieved[1].position, 1)
    }

    func testChunkCascadeDelete() throws {
        // Insert document with chunks
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 500,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 1
        )
        let docId = try db.insertDocument(document)

        let chunk = Chunk(
            id: 0,
            docId: docId,
            text: "Test chunk",
            embedding: [0.1, 0.2],
            position: 0,
            meta: ChunkMetadata(startOffset: 0, endOffset: 10, tokenCount: 2),
            createdAt: Date()
        )
        try db.insertChunks([chunk])

        // Verify chunk exists
        XCTAssertEqual(try db.getChunks(forDocumentId: docId).count, 1)

        // Delete document (should cascade to chunks)
        try db.deleteDocument(id: docId)

        // Verify chunks are also deleted
        XCTAssertEqual(try db.getChunks(forDocumentId: docId).count, 0)
    }

    func testChunkCount() throws {
        XCTAssertEqual(try db.getChunkCount(), 0)

        // Insert document
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 500,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 3
        )
        let docId = try db.insertDocument(document)

        // Insert chunks
        for i in 0..<3 {
            let chunk = Chunk(
                id: 0,
                docId: docId,
                text: "Chunk \(i)",
                embedding: [Float(i), Float(i + 1)],
                position: i,
                meta: ChunkMetadata(startOffset: i * 10, endOffset: (i + 1) * 10, tokenCount: 2),
                createdAt: Date()
            )
            try db.insertChunks([chunk])
        }

        XCTAssertEqual(try db.getChunkCount(), 3)
    }

    // MARK: - Vector Search Tests

    func testVectorSimilaritySearch() throws {
        // Insert document
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 1000,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 3
        )
        let docId = try db.insertDocument(document)

        // Insert chunks with different embeddings
        let chunks = [
            Chunk(
                id: 0,
                docId: docId,
                text: "Very similar to query",
                embedding: [1.0, 0.0, 0.0], // Close to query
                position: 0,
                meta: ChunkMetadata(startOffset: 0, endOffset: 20, tokenCount: 4),
                createdAt: Date()
            ),
            Chunk(
                id: 0,
                docId: docId,
                text: "Somewhat related",
                embedding: [0.7, 0.3, 0.0], // Moderately similar
                position: 1,
                meta: ChunkMetadata(startOffset: 21, endOffset: 40, tokenCount: 2),
                createdAt: Date()
            ),
            Chunk(
                id: 0,
                docId: docId,
                text: "Not related at all",
                embedding: [0.0, 0.0, 1.0], // Very different
                position: 2,
                meta: ChunkMetadata(startOffset: 41, endOffset: 60, tokenCount: 4),
                createdAt: Date()
            )
        ]
        try db.insertChunks(chunks)

        // Search with query embedding similar to first chunk
        let queryEmbedding: [Float] = [0.9, 0.1, 0.0]
        let results = try db.searchSimilar(queryEmbedding: queryEmbedding, topK: 2)

        // Verify results
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].chunk.text, "Very similar to query")
        XCTAssertEqual(results[1].chunk.text, "Somewhat related")

        // Verify scores are in descending order
        XCTAssertGreaterThan(results[0].score, results[1].score)

        // Verify document is included in results
        XCTAssertEqual(results[0].document.id, docId)
    }

    func testVectorSearchWithNoResults() throws {
        // Empty database should return no results
        let results = try db.searchSimilar(queryEmbedding: [1.0, 0.0], topK: 5)
        XCTAssertEqual(results.count, 0)
    }

    func testCosineSimilarityCalculation() throws {
        // Insert document with known embeddings
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 100,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 1
        )
        let docId = try db.insertDocument(document)

        // Identical vectors should have similarity = 1.0
        let identicalChunk = Chunk(
            id: 0,
            docId: docId,
            text: "Identical",
            embedding: [1.0, 0.0, 0.0],
            position: 0,
            meta: ChunkMetadata(startOffset: 0, endOffset: 9, tokenCount: 1),
            createdAt: Date()
        )
        try db.insertChunks([identicalChunk])

        let queryEmbedding: [Float] = [1.0, 0.0, 0.0]
        let results = try db.searchSimilar(queryEmbedding: queryEmbedding, topK: 1)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].score, 1.0, accuracy: 0.0001)
    }

    // MARK: - Metadata Tests

    func testChunkMetadataRoundtrip() throws {
        // Insert document
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 100,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 1
        )
        let docId = try db.insertDocument(document)

        // Insert chunk with metadata
        let meta = ChunkMetadata(
            startOffset: 100,
            endOffset: 200,
            tokenCount: 25,
            pageNumber: 5
        )

        let chunk = Chunk(
            id: 0,
            docId: docId,
            text: "Test chunk with metadata",
            embedding: [0.5, 0.5],
            position: 0,
            meta: meta,
            createdAt: Date()
        )
        try db.insertChunks([chunk])

        // Retrieve and verify metadata
        let retrieved = try db.getChunks(forDocumentId: docId)
        XCTAssertEqual(retrieved[0].meta.startOffset, 100)
        XCTAssertEqual(retrieved[0].meta.endOffset, 200)
        XCTAssertEqual(retrieved[0].meta.tokenCount, 25)
        XCTAssertEqual(retrieved[0].meta.pageNumber, 5)
    }
}
