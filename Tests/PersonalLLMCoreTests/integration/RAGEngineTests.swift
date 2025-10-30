import XCTest
@testable import PersonalLLMCore

final class RAGEngineTests: XCTestCase {
    var db: SQLiteVectorDB!
    var embedder: MockEmbedder!
    var llm: MockLLM!
    var chunker: TextChunker!
    var ingestion: DocumentIngestion!
    var ragEngine: RAGEngine!
    var tempDBPath: URL!

    override func setUp() async throws {
        // Create temporary database
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")

        // Initialize components
        db = try SQLiteVectorDB(dbPath: tempDBPath)
        embedder = MockEmbedder(dimension: 384, maxLength: 512, deterministicMode: true)
        llm = MockLLM(delay: .milliseconds(1))
        chunker = SemanticChunker()

        // Initialize ingestion pipeline
        ingestion = DocumentIngestion(
            chunker: chunker,
            embedder: embedder,
            database: db
        )

        // Load LLM
        let mockURL = URL(fileURLWithPath: "/mock/model")
        try await llm.load(modelPath: mockURL, config: .phi3Mini)

        // Initialize RAG engine
        ragEngine = RAGEngine(
            embedder: embedder,
            database: db,
            llm: llm,
            config: .default
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDBPath)
        db = nil
        embedder = nil
        llm = nil
        chunker = nil
        ingestion = nil
        ragEngine = nil
        tempDBPath = nil
    }

    // MARK: - Text Chunking Tests

    func testSemanticChunking() {
        let text = """
        This is the first sentence. This is the second sentence.
        This is the third sentence. And here's the fourth one.

        This is a new paragraph. It has multiple sentences too.
        Here's another sentence in this paragraph.
        """

        let chunks = chunker.chunk(text: text, maxTokens: 30, overlap: 10)

        XCTAssertFalse(chunks.isEmpty)
        XCTAssertGreaterThan(chunks.count, 1)

        // Each chunk should be non-empty
        for chunk in chunks {
            XCTAssertFalse(chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testChunkingWithLongSentence() {
        let longSentence = String(repeating: "word ", count: 500)
        let chunks = chunker.chunk(text: longSentence, maxTokens: 50, overlap: 10)

        XCTAssertGreaterThan(chunks.count, 1)
    }

    func testFixedSizeChunker() {
        let fixedChunker = FixedSizeChunker()
        let text = String(repeating: "This is a test sentence. ", count: 50)

        let chunks = fixedChunker.chunk(text: text, maxTokens: 100, overlap: 20)

        XCTAssertFalse(chunks.isEmpty)
        XCTAssertGreaterThan(chunks.count, 1)
    }

    // MARK: - Document Ingestion Tests

    func testIngestTextDocument() async throws {
        let text = """
        Swift is a powerful and intuitive programming language.
        It was developed by Apple for iOS, macOS, and other platforms.
        Swift is designed to be safe, fast, and expressive.
        """

        let document = try await ingestion.ingestText(
            text,
            filename: "swift_info.txt",
            maxChunkTokens: 50,
            chunkOverlap: 10
        )

        XCTAssertEqual(document.filename, "swift_info.txt")
        XCTAssertEqual(document.mimeType, "text/plain")
        XCTAssertGreaterThan(document.id, 0)

        // Verify chunks were created
        let chunks = try db.getChunks(forDocumentId: document.id)
        XCTAssertFalse(chunks.isEmpty)

        // All chunks should have embeddings
        for chunk in chunks {
            XCTAssertNotNil(chunk.embedding)
            XCTAssertEqual(chunk.embedding?.count, 384)
        }
    }

    func testIngestMultipleDocuments() async throws {
        let docs = [
            "Document 1: Swift is a programming language.",
            "Document 2: Python is also a programming language.",
            "Document 3: JavaScript runs in web browsers."
        ]

        for (index, text) in docs.enumerated() {
            _ = try await ingestion.ingestText(
                text,
                filename: "doc\(index + 1).txt"
            )
        }

        let allDocs = try db.getAllDocuments()
        XCTAssertEqual(allDocs.count, 3)

        let totalChunks = try db.getChunkCount()
        XCTAssertGreaterThan(totalChunks, 0)
    }

    // MARK: - RAG Engine Tests

    func testBasicRAGQuery() async throws {
        // Ingest test documents
        let doc1 = """
        The iPhone is a smartphone made by Apple Inc.
        It runs iOS and has features like Face ID and the App Store.
        """

        let doc2 = """
        Android is a mobile operating system developed by Google.
        It powers billions of devices worldwide.
        """

        _ = try await ingestion.ingestText(doc1, filename: "iphone.txt")
        _ = try await ingestion.ingestText(doc2, filename: "android.txt")

        // Query about iPhone
        let response = try await ragEngine.answerComplete(
            query: "What is the iPhone?",
            topK: 3
        )

        XCTAssertFalse(response.answer.isEmpty)
        XCTAssertFalse(response.citations.isEmpty)
        XCTAssertEqual(response.query, "What is the iPhone?")

        // Response should reference iPhone (mock echoes the query)
        XCTAssertTrue(response.answer.contains("iPhone") || response.answer.contains("What is"))
    }

    func testRAGWithStreaming() async throws {
        // Ingest document
        let text = "Retrieval-Augmented Generation combines retrieval with language models."
        _ = try await ingestion.ingestText(text, filename: "rag_def.txt")

        // Query with streaming
        let (stream, citations) = try await ragEngine.answer(
            query: "What is RAG?",
            topK: 2
        )

        XCTAssertFalse(citations.isEmpty)

        // Collect tokens
        var tokens: [String] = []
        for await token in stream {
            tokens.append(token)
        }

        XCTAssertFalse(tokens.isEmpty)

        let fullResponse = tokens.joined()
        XCTAssertFalse(fullResponse.isEmpty)
    }

    func testCitationTracking() async throws {
        // Ingest multiple documents
        _ = try await ingestion.ingestText(
            "Cats are domestic animals.",
            filename: "cats.txt"
        )
        _ = try await ingestion.ingestText(
            "Dogs are loyal companions.",
            filename: "dogs.txt"
        )

        // Query
        let response = try await ragEngine.answerComplete(
            query: "Tell me about cats",
            topK: 3
        )

        // Should have citations
        XCTAssertFalse(response.citations.isEmpty)

        // Verify citation structure
        let citation = response.citations[0]
        XCTAssertNotNil(citation.id)
        XCTAssertFalse(citation.documentName.isEmpty)
        XCTAssertGreaterThan(citation.documentId, 0)
        XCTAssertFalse(citation.chunkText.isEmpty)
        // Cosine similarity ranges from -1 to 1
        XCTAssertGreaterThanOrEqual(citation.relevanceScore, -1)
        XCTAssertLessThanOrEqual(citation.relevanceScore, 1)

        // Test formatted citation
        let formatted = citation.formatted
        XCTAssertTrue(formatted.contains("Source"))
        XCTAssertTrue(formatted.contains(citation.documentName))
    }

    func testRAGWithEmptyDatabase() async throws {
        // Query without any documents
        let response = try await ragEngine.answerComplete(
            query: "What is quantum computing?",
            topK: 5
        )

        // Should still get a response (saying no information available)
        XCTAssertFalse(response.answer.isEmpty)
        XCTAssertTrue(response.citations.isEmpty)
    }

    func testRAGConfigurationPresets() async throws {
        // Test different configurations
        let configs: [RAGConfig] = [.default, .accurate, .creative]

        for config in configs {
            let engine = RAGEngine(
                embedder: embedder,
                database: db,
                llm: llm,
                config: config
            )

            // Ingest test document
            _ = try await ingestion.ingestText(
                "Test document for configuration testing.",
                filename: "config_test.txt"
            )

            let response = try await engine.answerComplete(
                query: "What is this test about?",
                topK: 2
            )

            XCTAssertFalse(response.answer.isEmpty)
        }
    }

    func testRAGContextAssembly() async throws {
        // Ingest document with multiple chunks
        let longText = """
        First paragraph about topic A.

        Second paragraph about topic A with more details.

        Third paragraph about topic B.

        Fourth paragraph returning to topic A.
        """

        _ = try await ingestion.ingestText(
            longText,
            filename: "multi_topic.txt",
            maxChunkTokens: 30,
            chunkOverlap: 5
        )

        // Query should retrieve and assemble context
        let response = try await ragEngine.answerComplete(
            query: "Tell me about topic A",
            topK: 3
        )

        XCTAssertFalse(response.answer.isEmpty)
        XCTAssertFalse(response.citations.isEmpty)
        XCTAssertGreaterThanOrEqual(response.citations.count, 1)
    }

    // MARK: - End-to-End Integration Tests

    func testCompleteRAGPipeline() async throws {
        // 1. Ingest documents
        let docs = [
            ("The sky is blue during the day.", "sky.txt"),
            ("The ocean is vast and deep.", "ocean.txt"),
            ("Mountains are tall and majestic.", "mountains.txt")
        ]

        for (text, filename) in docs {
            _ = try await ingestion.ingestText(text, filename: filename)
        }

        // 2. Verify storage
        let allDocs = try db.getAllDocuments()
        XCTAssertEqual(allDocs.count, 3)

        // 3. Perform RAG query
        let response = try await ragEngine.answerComplete(
            query: "What color is the sky?",
            topK: 2
        )

        // 4. Verify response
        XCTAssertFalse(response.answer.isEmpty)
        XCTAssertFalse(response.citations.isEmpty)

        // 5. Verify relevant documents were cited
        // Check that at least one citation mentions sky
        let hasSkyReference = response.citations.contains { citation in
            citation.documentName == "sky.txt" ||
            citation.chunkText.lowercased().contains("sky")
        }
        XCTAssertTrue(hasSkyReference, "Expected at least one citation about sky")
    }

    func testRAGWithMultipleQueries() async throws {
        // Ingest knowledge base
        let knowledge = """
        Personal AI is a privacy-first AI assistant.
        It runs entirely on your device.
        All data stays local and encrypted.
        The app uses RAG for accurate responses.
        """

        _ = try await ingestion.ingestText(knowledge, filename: "personal_ai.txt")

        // Multiple queries
        let queries = [
            "What is Personal AI?",
            "How does it handle privacy?",
            "What technology does it use?"
        ]

        for query in queries {
            let response = try await ragEngine.answerComplete(
                query: query,
                topK: 2
            )

            XCTAssertFalse(response.answer.isEmpty)
            XCTAssertFalse(response.citations.isEmpty)
            XCTAssertEqual(response.query, query)
        }
    }

    func testFormattedResponse() async throws {
        // Ingest document
        _ = try await ingestion.ingestText(
            "Testing formatted responses with citations.",
            filename: "test.txt"
        )

        // Get response
        let response = try await ragEngine.answerComplete(
            query: "What is being tested?",
            topK: 1
        )

        // Test formatted output
        let formatted = response.formatted
        XCTAssertTrue(formatted.contains(response.answer))

        if !response.citations.isEmpty {
            XCTAssertTrue(formatted.contains("Sources:"))
        }
    }
}
