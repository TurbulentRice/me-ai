import Foundation

// MARK: - RAG Engine

/// Main engine for Retrieval-Augmented Generation
public final class RAGEngine: Sendable {
    private let embedder: Embedder
    private let database: VectorDatabase
    private let llm: LocalLLM
    private let config: RAGConfig

    public init(
        embedder: Embedder,
        database: VectorDatabase,
        llm: LocalLLM,
        config: RAGConfig = .default
    ) {
        self.embedder = embedder
        self.database = database
        self.llm = llm
        self.config = config
    }

    // MARK: - Query Methods

    /// Answer a question using RAG
    /// - Parameters:
    ///   - query: User's question
    ///   - topK: Number of context chunks to retrieve
    ///   - systemPrompt: Optional custom system prompt
    /// - Returns: Tuple of streaming response and citations
    public func answer(
        query: String,
        topK: Int = 5,
        systemPrompt: String? = nil
    ) async throws -> (stream: AsyncStream<String>, citations: [Citation]) {
        // 1. Embed the query
        let queryEmbedding = try await embedder.embed(text: query)

        // 2. Retrieve relevant chunks
        let results = try database.searchSimilar(
            queryEmbedding: queryEmbedding,
            topK: topK
        )

        // 3. Build context from results
        let context = buildContext(from: results)

        // 4. Create citations
        let citations = results.enumerated().map { index, result in
            Citation(
                id: UUID(),
                documentName: result.document.filename,
                documentId: result.document.id,
                chunkText: result.chunk.text,
                chunkPosition: result.chunk.position,
                relevanceScore: result.score,
                sourceIndex: index + 1
            )
        }

        // 5. Check if LLM is loaded
        guard await llm.isLoaded else {
            throw RAGError.generationFailed("LLM model is still loading. Please wait a moment and try again.")
        }

        // 6. Build prompt
        let prompt = buildPrompt(
            query: query,
            context: context,
            citations: citations,
            systemPrompt: systemPrompt
        )

        // 7. Generate response
        let stream = try await llm.generate(
            prompt: prompt,
            stopSequences: config.stopSequences,
            maxTokens: config.maxResponseTokens,
            temperature: config.temperature
        )

        return (stream, citations)
    }

    /// Answer with a complete response (non-streaming)
    /// - Parameters:
    ///   - query: User's question
    ///   - topK: Number of context chunks to retrieve
    ///   - systemPrompt: Optional custom system prompt
    /// - Returns: Complete answer with citations
    public func answerComplete(
        query: String,
        topK: Int = 5,
        systemPrompt: String? = nil
    ) async throws -> RAGResponse {
        let (stream, citations) = try await answer(
            query: query,
            topK: topK,
            systemPrompt: systemPrompt
        )

        // Collect full response
        var fullResponse = ""
        for await token in stream {
            fullResponse += token
        }

        return RAGResponse(
            answer: fullResponse,
            citations: citations,
            query: query
        )
    }

    // MARK: - Context Assembly

    private func buildContext(from results: [SearchResult]) -> String {
        results.enumerated().map { index, result in
            let sourceNum = index + 1
            return """
            [Source \(sourceNum): \(result.document.filename)]
            \(result.chunk.text)
            """
        }.joined(separator: "\n\n---\n\n")
    }

    private func buildPrompt(
        query: String,
        context: String,
        citations: [Citation],
        systemPrompt: String?
    ) -> String {
        let system = systemPrompt ?? config.defaultSystemPrompt

        if context.isEmpty {
            // No context available
            return """
            \(system)

            User Question: \(query)

            Answer: I don't have any relevant information in my knowledge base to answer this question. Please add documents first.
            """
        }

        return """
        \(system)

        Context Information:
        \(context)

        User Question: \(query)

        Instructions:
        - Answer based on the provided context
        - Cite sources by mentioning the source numbers (e.g., "According to Source 1...")
        - If the context doesn't contain enough information, state that clearly
        - Be concise and accurate

        Answer:
        """
    }
}

// MARK: - RAG Configuration

/// Configuration for RAG engine behavior
public struct RAGConfig: Sendable {
    /// Default system prompt
    public let defaultSystemPrompt: String

    /// Stop sequences for generation
    public let stopSequences: [String]

    /// Maximum tokens in response
    public let maxResponseTokens: Int

    /// Temperature for generation
    public let temperature: Float

    /// Include source citations in response
    public let includeCitations: Bool

    public init(
        defaultSystemPrompt: String,
        stopSequences: [String],
        maxResponseTokens: Int,
        temperature: Float,
        includeCitations: Bool
    ) {
        self.defaultSystemPrompt = defaultSystemPrompt
        self.stopSequences = stopSequences
        self.maxResponseTokens = maxResponseTokens
        self.temperature = temperature
        self.includeCitations = includeCitations
    }

    /// Default configuration
    public static let `default` = RAGConfig(
        defaultSystemPrompt: """
        You are a helpful AI assistant. Answer questions based on the provided context.
        Be accurate, concise, and cite your sources when possible.
        """,
        stopSequences: ["User Question:", "</s>", "<|end|>"],
        maxResponseTokens: 512,
        temperature: 0.7,
        includeCitations: true
    )

    /// Configuration optimized for accuracy
    public static let accurate = RAGConfig(
        defaultSystemPrompt: """
        You are a precise AI assistant. Provide accurate answers based strictly on the provided context.
        Always cite specific sources. If information is not in the context, state that clearly.
        """,
        stopSequences: ["User Question:", "</s>"],
        maxResponseTokens: 300,
        temperature: 0.3,
        includeCitations: true
    )

    /// Configuration optimized for creativity
    public static let creative = RAGConfig(
        defaultSystemPrompt: """
        You are a creative AI assistant. Use the provided context as inspiration
        to provide helpful, engaging answers.
        """,
        stopSequences: ["User Question:", "</s>"],
        maxResponseTokens: 700,
        temperature: 0.9,
        includeCitations: true
    )
}

// MARK: - Citation Model

/// Citation for a retrieved chunk
public struct Citation: Sendable, Identifiable {
    public let id: UUID
    public let documentName: String
    public let documentId: Int64
    public let chunkText: String
    public let chunkPosition: Int
    public let relevanceScore: Float
    public let sourceIndex: Int

    public init(
        id: UUID = UUID(),
        documentName: String,
        documentId: Int64,
        chunkText: String,
        chunkPosition: Int,
        relevanceScore: Float,
        sourceIndex: Int
    ) {
        self.id = id
        self.documentName = documentName
        self.documentId = documentId
        self.chunkText = chunkText
        self.chunkPosition = chunkPosition
        self.relevanceScore = relevanceScore
        self.sourceIndex = sourceIndex
    }

    /// Formatted citation text
    public var formatted: String {
        """
        Source \(sourceIndex): \(documentName) (relevance: \(String(format: "%.2f", relevanceScore)))
        \(String(chunkText.prefix(100)))...
        """
    }
}

// MARK: - RAG Response

/// Complete response from RAG engine
public struct RAGResponse: Sendable {
    public let answer: String
    public let citations: [Citation]
    public let query: String
    public let timestamp: Date

    public init(
        answer: String,
        citations: [Citation],
        query: String,
        timestamp: Date = Date()
    ) {
        self.answer = answer
        self.citations = citations
        self.query = query
        self.timestamp = timestamp
    }

    /// Formatted response with citations
    public var formatted: String {
        var result = answer

        if !citations.isEmpty {
            result += "\n\n---\n\nSources:\n"
            for citation in citations {
                result += "\n\(citation.formatted)"
            }
        }

        return result
    }
}

// MARK: - RAG Errors

/// Errors specific to RAG operations
public enum RAGError: Error, LocalizedError {
    case noContext
    case generationFailed(String)
    case embeddingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noContext:
            return "No relevant context found in knowledge base"
        case .generationFailed(let message):
            return "Response generation failed: \(message)"
        case .embeddingFailed(let message):
            return "Query embedding failed: \(message)"
        }
    }
}
