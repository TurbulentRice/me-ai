import XCTest
@testable import PersonalLLMCore

/// End-to-end integration tests covering complete user workflows
final class EndToEndTests: XCTestCase {
    var tempDBPath: URL!
    var database: VectorDatabase!
    var embedder: Embedder!
    var llm: LocalLLM!
    var ragEngine: RAGEngine!
    var documentManager: DocumentManager!

    override func setUp() async throws {
        // Create temporary database
        tempDBPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")

        // Initialize components
        database = try SQLiteVectorDB(dbPath: tempDBPath)
        embedder = MockEmbedder(dimension: 384)
        llm = MockLLM(delay: .milliseconds(10))

        let config = RAGConfiguration(
            topK: 3,
            chunkSize: 512,
            chunkOverlap: 50,
            maxContextTokens: 2048,
            systemPrompt: "You are a helpful assistant."
        )

        ragEngine = RAGEngine(
            database: database,
            embedder: embedder,
            llm: llm,
            config: config
        )

        documentManager = DocumentManager(
            database: database,
            ingestion: DocumentIngestion(
                chunker: SemanticChunker(),
                embedder: embedder,
                database: database
            )
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDBPath)
    }

    // MARK: - End-to-End Workflows

    func testCompleteUserWorkflow() async throws {
        // Simulate a complete user workflow:
        // 1. User ingests a document
        // 2. User asks a question
        // 3. System retrieves relevant chunks
        // 4. System generates answer with citations

        // Step 1: Ingest document
        let documentContent = """
        Swift is a powerful and intuitive programming language for iOS, macOS, and more.
        It's designed to work with Apple's Cocoa and Cocoa Touch frameworks.
        Swift is modern, safe, and fast, making it a great choice for app development.
        The language includes many features like optionals, generics, and protocols.
        """

        let document = try await documentManager.ingestText(
            documentContent,
            filename: "swift_intro.txt",
            mimeType: "text/plain"
        )

        XCTAssertGreaterThan(document.id, 0, "Document should be inserted")
        XCTAssertGreaterThan(document.chunkCount, 0, "Document should have chunks")

        // Step 2: User asks a question
        let query = "What is Swift?"

        // Step 3 & 4: System generates answer with citations
        let (stream, citations) = try await ragEngine.answerQuery(query)

        var fullResponse = ""
        for await token in stream {
            fullResponse += token
        }

        // Verify results
        XCTAssertFalse(fullResponse.isEmpty, "Should generate a response")
        XCTAssertFalse(citations.isEmpty, "Should include citations")
        XCTAssertEqual(citations[0].documentName, "swift_intro.txt", "Citation should reference correct document")
    }

    func testMultiDocumentWorkflow() async throws {
        // Test working with multiple documents

        // Ingest first document
        let doc1Content = """
        Python is a high-level programming language known for its simplicity.
        It's widely used in data science, web development, and automation.
        Python has a clean syntax and extensive library support.
        """

        let doc1 = try await documentManager.ingestText(
            doc1Content,
            filename: "python.txt",
            mimeType: "text/plain"
        )

        // Ingest second document
        let doc2Content = """
        JavaScript is the language of the web, running in browsers.
        It enables interactive web pages and modern web applications.
        Node.js brings JavaScript to server-side development.
        """

        let doc2 = try await documentManager.ingestText(
            doc2Content,
            filename: "javascript.txt",
            mimeType: "text/plain"
        )

        // Verify both documents exist
        let allDocs = try database.getAllDocuments()
        XCTAssertEqual(allDocs.count, 2, "Should have 2 documents")

        // Query should retrieve relevant context from both
        let (stream, citations) = try await ragEngine.answerQuery("What programming languages are discussed?")

        var response = ""
        for await token in stream {
            response += token
        }

        XCTAssertFalse(response.isEmpty, "Should generate response")

        // Should have citations from at least one document
        XCTAssertGreaterThan(citations.count, 0, "Should have citations")
    }

    func testDocumentDeletionWorkflow() async throws {
        // Test complete document lifecycle: ingest -> query -> delete -> verify

        // Ingest document
        let content = "This is a test document that will be deleted."
        let doc = try await documentManager.ingestText(
            content,
            filename: "temp.txt",
            mimeType: "text/plain"
        )

        // Verify document exists
        let beforeDelete = try database.getAllDocuments()
        XCTAssertEqual(beforeDelete.count, 1)

        // Delete document
        try documentManager.deleteDocument(id: doc.id)

        // Verify deletion
        let afterDelete = try database.getAllDocuments()
        XCTAssertEqual(afterDelete.count, 0, "Document should be deleted")

        // Verify chunks are also deleted (cascade)
        let chunks = try database.getChunks(forDocumentId: doc.id)
        XCTAssertEqual(chunks.count, 0, "Chunks should be cascade deleted")
    }

    func testErrorRecoveryWorkflow() async throws {
        // Test system behavior with invalid inputs

        // Try to query empty database
        let (stream, citations) = try await ragEngine.answerQuery("What is in the database?")

        var response = ""
        for await token in stream {
            response += token
        }

        // Should still generate a response (even if it says no data available)
        XCTAssertFalse(response.isEmpty, "Should generate response even with empty database")
        XCTAssertTrue(citations.isEmpty, "Should have no citations with empty database")

        // Try to delete non-existent document
        XCTAssertThrowsError(try database.deleteDocument(id: 99999)) { error in
            XCTAssertTrue(error is StorageError, "Should throw StorageError")
        }
    }

    func testConcurrentQueriesWorkflow() async throws {
        // Test multiple concurrent queries

        // Ingest test data
        let content = """
        Artificial Intelligence is transforming technology.
        Machine Learning is a subset of AI focused on learning from data.
        Deep Learning uses neural networks with many layers.
        Natural Language Processing enables computers to understand human language.
        """

        _ = try await documentManager.ingestText(
            content,
            filename: "ai_concepts.txt",
            mimeType: "text/plain"
        )

        // Run multiple queries concurrently
        async let query1 = ragEngine.answerQuery("What is AI?")
        async let query2 = ragEngine.answerQuery("What is Machine Learning?")
        async let query3 = ragEngine.answerQuery("What is Deep Learning?")

        let (stream1, citations1) = try await query1
        let (stream2, citations2) = try await query2
        let (stream3, citations3) = try await query3

        // Consume streams
        var response1 = ""
        for await token in stream1 { response1 += token }

        var response2 = ""
        for await token in stream2 { response2 += token }

        var response3 = ""
        for await token in stream3 { response3 += token }

        // All queries should succeed
        XCTAssertFalse(response1.isEmpty)
        XCTAssertFalse(response2.isEmpty)
        XCTAssertFalse(response3.isEmpty)

        // All should have citations
        XCTAssertFalse(citations1.isEmpty)
        XCTAssertFalse(citations2.isEmpty)
        XCTAssertFalse(citations3.isEmpty)
    }

    func testLargeDocumentWorkflow() async throws {
        // Test with a large document that requires multiple chunks

        // Generate large content (~10KB)
        let paragraph = """
        This is a paragraph of text that will be repeated many times to create a large document.
        It contains information about various topics and will be split into multiple chunks.
        The chunking algorithm should handle this properly and create overlapping chunks.
        """

        let largeContent = String(repeating: paragraph + "\n\n", count: 50)

        let doc = try await documentManager.ingestText(
            largeContent,
            filename: "large_doc.txt",
            mimeType: "text/plain"
        )

        // Verify multiple chunks were created
        XCTAssertGreaterThan(doc.chunkCount, 5, "Large document should create multiple chunks")

        // Query should still work efficiently
        let startTime = Date()
        let (stream, citations) = try await ragEngine.answerQuery("What is in the document?")

        var response = ""
        for await token in stream {
            response += token
        }
        let endTime = Date()

        // Verify performance
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 5.0, "Query should complete in reasonable time")

        // Verify results
        XCTAssertFalse(response.isEmpty)
        XCTAssertGreaterThan(citations.count, 0)
    }

    func testStreamingResponseWorkflow() async throws {
        // Test that streaming works correctly

        // Ingest test document
        let content = "This is a test document for streaming."
        _ = try await documentManager.ingestText(
            content,
            filename: "stream_test.txt",
            mimeType: "text/plain"
        )

        // Query and collect tokens with timestamps
        let (stream, _) = try await ragEngine.answerQuery("What is this?")

        var tokens: [String] = []
        var receivedTokenCount = 0

        for await token in stream {
            tokens.append(token)
            receivedTokenCount += 1

            // Verify we're receiving tokens incrementally
            XCTAssertFalse(token.isEmpty, "Each token should be non-empty")
        }

        // Verify streaming happened (multiple tokens received)
        XCTAssertGreaterThan(receivedTokenCount, 1, "Should receive multiple streaming tokens")

        // Verify final response is coherent
        let fullResponse = tokens.joined()
        XCTAssertFalse(fullResponse.isEmpty)
    }

    // MARK: - Performance Tests

    func testQueryPerformance() async throws {
        // Measure query performance

        // Ingest test data
        let content = "Swift is a programming language for iOS development."
        _ = try await documentManager.ingestText(
            content,
            filename: "perf_test.txt",
            mimeType: "text/plain"
        )

        // Measure query time
        measure {
            let expectation = self.expectation(description: "Query completes")

            Task {
                let (stream, _) = try await self.ragEngine.answerQuery("What is Swift?")
                var response = ""
                for await token in stream {
                    response += token
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testIngestionPerformance() async throws {
        // Measure document ingestion performance

        let content = String(repeating: "Test content. ", count: 100)

        measure {
            let expectation = self.expectation(description: "Ingestion completes")

            Task {
                _ = try await self.documentManager.ingestText(
                    content,
                    filename: "perf_\(UUID().uuidString).txt",
                    mimeType: "text/plain"
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}
