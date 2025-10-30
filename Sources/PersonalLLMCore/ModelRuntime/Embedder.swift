import Foundation

// MARK: - Embedder Protocol

/// Protocol for generating text embeddings
public protocol Embedder: Sendable {
    /// Generate embeddings for multiple texts
    /// - Parameter texts: Array of text strings to embed
    /// - Returns: Array of embedding vectors (one per input text)
    func embed(texts: [String]) async throws -> [[Float]]

    /// Generate embedding for a single text
    /// - Parameter text: Text string to embed
    /// - Returns: Embedding vector
    func embed(text: String) async throws -> [Float]

    /// Get the dimensionality of embeddings produced by this embedder
    var embeddingDimension: Int { get async }

    /// Maximum sequence length supported by the embedder
    var maxSequenceLength: Int { get async }
}

// MARK: - Default Implementation

public extension Embedder {
    /// Default implementation for single text embedding
    func embed(text: String) async throws -> [Float] {
        let results = try await embed(texts: [text])
        guard let embedding = results.first else {
            throw EmbeddingError.embeddingFailed("No embedding generated")
        }
        return embedding
    }
}

// MARK: - Embedding Errors

/// Errors that can occur during embedding operations
public enum EmbeddingError: Error, LocalizedError {
    case modelNotLoaded
    case embeddingFailed(String)
    case invalidInput(String)
    case dimensionMismatch
    case sequenceTooLong(Int, Int) // actual, max

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Embedding model not loaded"
        case .embeddingFailed(let message):
            return "Embedding generation failed: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .dimensionMismatch:
            return "Embedding dimension mismatch"
        case .sequenceTooLong(let actual, let max):
            return "Sequence length \(actual) exceeds maximum \(max)"
        }
    }
}

// MARK: - Mock Embedder Implementation

/// Mock embedder for testing and development
public final class MockEmbedder: Embedder {
    private let dimension: Int
    private let maxLength: Int
    private let deterministicMode: Bool

    public var embeddingDimension: Int {
        get async { dimension }
    }

    public var maxSequenceLength: Int {
        get async { maxLength }
    }

    /// Initialize mock embedder
    /// - Parameters:
    ///   - dimension: Embedding vector dimension
    ///   - maxLength: Maximum sequence length
    ///   - deterministicMode: If true, generates deterministic embeddings based on text hash
    public init(
        dimension: Int = 384,
        maxLength: Int = 512,
        deterministicMode: Bool = true
    ) {
        self.dimension = dimension
        self.maxLength = maxLength
        self.deterministicMode = deterministicMode
    }

    public func embed(texts: [String]) async throws -> [[Float]] {
        // Validate inputs
        for text in texts {
            let tokenCount = estimateTokenCount(text)
            if tokenCount > maxLength {
                throw EmbeddingError.sequenceTooLong(tokenCount, maxLength)
            }
        }

        // Simulate processing delay
        try await Task.sleep(for: .milliseconds(5 * texts.count))

        // Generate embeddings
        return texts.map { text in
            if deterministicMode {
                return generateDeterministicEmbedding(for: text)
            } else {
                return generateRandomEmbedding()
            }
        }
    }

    // MARK: - Private Helpers

    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token
        return text.count / 4
    }

    private func generateDeterministicEmbedding(for text: String) -> [Float] {
        // Generate embedding based on text hash for consistency
        var hasher = Hasher()
        hasher.combine(text)
        let seed = hasher.finalize()

        var generator = SeededRandomGenerator(seed: UInt64(truncatingIfNeeded: seed))

        return (0..<dimension).map { _ in
            Float(generator.next()) / Float(UInt64.max) * 2.0 - 1.0
        }
    }

    private func generateRandomEmbedding() -> [Float] {
        return (0..<dimension).map { _ in
            Float.random(in: -1.0...1.0)
        }
    }
}

// MARK: - Seeded Random Generator

/// Simple seeded random number generator for deterministic mock embeddings
private struct SeededRandomGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // Simple LCG (Linear Congruential Generator)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Stub for Real Embedder Implementation

/// Placeholder for real embedding model implementation
/// This will be replaced with actual CoreML or MLX implementation in future
public final class LocalEmbedder: Embedder {
    private let modelPath: URL
    private let dimension: Int
    private let maxLength: Int
    private var isLoaded = false

    public var embeddingDimension: Int {
        get async { dimension }
    }

    public var maxSequenceLength: Int {
        get async { maxLength }
    }

    /// Initialize local embedder
    /// - Parameters:
    ///   - modelPath: Path to the embedding model (CoreML or ONNX)
    ///   - dimension: Expected embedding dimension
    ///   - maxLength: Maximum sequence length
    public init(
        modelPath: URL,
        dimension: Int = 384,
        maxLength: Int = 512
    ) {
        self.modelPath = modelPath
        self.dimension = dimension
        self.maxLength = maxLength
    }

    public func embed(texts: [String]) async throws -> [[Float]] {
        // TODO: Implement actual embedding model inference
        // For now, throw not implemented error
        throw EmbeddingError.embeddingFailed("Real embedding implementation not yet available. Use MockEmbedder for testing.")

        // Future implementation will:
        // 1. Load CoreML model
        // 2. Tokenize input texts
        // 3. Run inference
        // 4. Extract embeddings from model output
        // 5. Normalize vectors if needed
    }

    /// Load the embedding model
    private func loadModel() async throws {
        // TODO: Implement model loading
        // This will use CoreML or MLX depending on platform
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw EmbeddingError.modelNotLoaded
        }

        isLoaded = true
    }
}
