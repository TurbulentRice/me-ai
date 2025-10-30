import XCTest
@testable import PersonalLLMCore

final class ModelRuntimeTests: XCTestCase {

    // MARK: - LocalLLM Tests

    func testMockLLMLoading() async throws {
        let llm = MockLLM()

        // Initially not loaded
        let isLoadedBefore = await llm.isLoaded
        XCTAssertFalse(isLoadedBefore)

        // Load model
        let mockURL = URL(fileURLWithPath: "/mock/model/path")
        try await llm.load(modelPath: mockURL, config: .phi3Mini)

        // Should be loaded now
        let isLoadedAfter = await llm.isLoaded
        XCTAssertTrue(isLoadedAfter)

        // Model info should be available
        let modelInfo = await llm.modelInfo
        XCTAssertNotNil(modelInfo)
        XCTAssertEqual(modelInfo?.name, "mock-model")
        XCTAssertEqual(modelInfo?.architecture, "mock")
    }

    func testMockLLMGeneration() async throws {
        let llm = MockLLM(delay: .milliseconds(1)) // Fast for testing

        // Load model
        let mockURL = URL(fileURLWithPath: "/mock/model/path")
        try await llm.load(modelPath: mockURL, config: .phi3Mini)

        // Generate text
        let stream = try await llm.generate(
            prompt: "Hello world",
            stopSequences: ["\n"],
            maxTokens: 50,
            temperature: 0.7
        )

        // Collect generated tokens
        var tokens: [String] = []
        for await token in stream {
            tokens.append(token)
        }

        // Should generate response
        XCTAssertFalse(tokens.isEmpty)

        // Should contain prompt echo in response
        let fullResponse = tokens.joined()
        XCTAssertTrue(fullResponse.contains("Hello world"))
    }

    func testMockLLMUnload() async throws {
        let llm = MockLLM()

        // Load model
        let mockURL = URL(fileURLWithPath: "/mock/model/path")
        try await llm.load(modelPath: mockURL, config: .phi3Mini)

        var isLoaded = await llm.isLoaded
        XCTAssertTrue(isLoaded)

        // Unload model
        try await llm.unload()

        isLoaded = await llm.isLoaded
        XCTAssertFalse(isLoaded)

        // Model info should be nil
        let modelInfo = await llm.modelInfo
        XCTAssertNil(modelInfo)
    }

    func testMockLLMGenerationWithoutLoading() async throws {
        let llm = MockLLM()

        // Try to generate without loading
        do {
            let _ = try await llm.generate(
                prompt: "Test",
                stopSequences: [],
                maxTokens: 10,
                temperature: 0.7
            )
            XCTFail("Should throw modelNotLoaded error")
        } catch ModelRuntimeError.modelNotLoaded {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testLLMConfigDefaults() {
        let phi3Config = LLMConfig.phi3Mini
        XCTAssertEqual(phi3Config.contextLength, 8192)
        XCTAssertEqual(phi3Config.temperature, 0.7)
        XCTAssertEqual(phi3Config.topP, 0.95)
        XCTAssertEqual(phi3Config.topK, 50)

        let gemmaConfig = LLMConfig.gemma2B
        XCTAssertEqual(gemmaConfig.contextLength, 4096)
        XCTAssertEqual(gemmaConfig.topK, 40)
    }

    // MARK: - Embedder Tests

    func testMockEmbedderSingleText() async throws {
        let embedder = MockEmbedder(dimension: 384, maxLength: 512)

        // Get embedding dimension
        let dimension = await embedder.embeddingDimension
        XCTAssertEqual(dimension, 384)

        // Generate embedding
        let embedding = try await embedder.embed(text: "Hello world")

        // Check dimension
        XCTAssertEqual(embedding.count, 384)

        // Check values are in valid range
        for value in embedding {
            XCTAssertGreaterThanOrEqual(value, -1.0)
            XCTAssertLessThanOrEqual(value, 1.0)
        }
    }

    func testMockEmbedderMultipleTexts() async throws {
        let embedder = MockEmbedder(dimension: 128, maxLength: 256)

        let texts = [
            "First text",
            "Second text",
            "Third text"
        ]

        let embeddings = try await embedder.embed(texts: texts)

        // Should return one embedding per text
        XCTAssertEqual(embeddings.count, 3)

        // Each embedding should have correct dimension
        for embedding in embeddings {
            XCTAssertEqual(embedding.count, 128)
        }
    }

    func testMockEmbedderDeterministic() async throws {
        let embedder = MockEmbedder(
            dimension: 256,
            maxLength: 512,
            deterministicMode: true
        )

        let text = "Test text for deterministic embedding"

        // Generate embedding twice
        let embedding1 = try await embedder.embed(text: text)
        let embedding2 = try await embedder.embed(text: text)

        // Should be identical in deterministic mode
        XCTAssertEqual(embedding1.count, embedding2.count)
        for (v1, v2) in zip(embedding1, embedding2) {
            XCTAssertEqual(v1, v2, accuracy: 0.0001)
        }
    }

    func testMockEmbedderDifferentTexts() async throws {
        let embedder = MockEmbedder(
            dimension: 256,
            maxLength: 512,
            deterministicMode: true
        )

        let embedding1 = try await embedder.embed(text: "First text")
        let embedding2 = try await embedder.embed(text: "Second text")

        // Different texts should produce different embeddings
        XCTAssertNotEqual(embedding1, embedding2)
    }

    func testMockEmbedderSequenceTooLong() async throws {
        let embedder = MockEmbedder(dimension: 128, maxLength: 100)

        // Create text that's too long (>400 characters = ~100 tokens)
        let longText = String(repeating: "word ", count: 200)

        do {
            let _ = try await embedder.embed(text: longText)
            XCTFail("Should throw sequenceTooLong error")
        } catch EmbeddingError.sequenceTooLong {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testMockEmbedderMaxLength() async throws {
        let embedder = MockEmbedder(dimension: 384, maxLength: 512)

        let maxLength = await embedder.maxSequenceLength
        XCTAssertEqual(maxLength, 512)
    }

    // MARK: - Integration Tests

    func testLLMAndEmbedderTogether() async throws {
        // Initialize both LLM and embedder
        let llm = MockLLM(delay: .milliseconds(1))
        let embedder = MockEmbedder(dimension: 384, maxLength: 512)

        // Load LLM
        let mockURL = URL(fileURLWithPath: "/mock/model/path")
        try await llm.load(modelPath: mockURL, config: .phi3Mini)

        // Generate a query
        let query = "What is the meaning of life?"

        // Get query embedding
        let queryEmbedding = try await embedder.embed(text: query)
        XCTAssertEqual(queryEmbedding.count, 384)

        // Generate response
        let stream = try await llm.generate(
            prompt: query,
            stopSequences: ["\n"],
            maxTokens: 100,
            temperature: 0.7
        )

        var response = ""
        for await token in stream {
            response += token
        }

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.contains("meaning of life"))
    }

    func testEmbedMultipleDocuments() async throws {
        let embedder = MockEmbedder(
            dimension: 384,
            maxLength: 512,
            deterministicMode: true
        )

        // Simulate multiple document chunks
        let chunks = [
            "The quick brown fox jumps over the lazy dog.",
            "Swift is a powerful and intuitive programming language.",
            "Machine learning enables computers to learn from data.",
            "The Personal AI app runs entirely on your device."
        ]

        let embeddings = try await embedder.embed(texts: chunks)

        XCTAssertEqual(embeddings.count, 4)

        // All embeddings should have same dimension
        for embedding in embeddings {
            XCTAssertEqual(embedding.count, 384)
        }

        // Calculate similarity between first and last (should be different topics)
        let similarity = cosineSimilarity(embeddings[0], embeddings[3])
        XCTAssertGreaterThan(similarity, -1.0)
        XCTAssertLessThan(similarity, 1.0)
    }

    // MARK: - Helper Functions

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }
}
