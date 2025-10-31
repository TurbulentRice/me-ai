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

// MARK: - CoreML Embedder Implementation

#if canImport(CoreML)
import CoreML

/// Real CoreML-based embedder using sentence-transformers model
public final class LocalEmbedder: Embedder {
    private let modelPath: URL
    private let dimension: Int
    private let maxLength: Int
    private var mlModel: MLModel?
    private let tokenizer: SimpleTokenizer

    public var embeddingDimension: Int {
        get async { dimension }
    }

    public var maxSequenceLength: Int {
        get async { maxLength }
    }

    /// Initialize local embedder
    /// - Parameters:
    ///   - modelPath: Path to the CoreML embedding model (.mlpackage)
    ///   - dimension: Expected embedding dimension (384 for all-MiniLM-L6-v2)
    ///   - maxLength: Maximum sequence length (128 default)
    public init(
        modelPath: URL,
        dimension: Int = 384,
        maxLength: Int = 128
    ) {
        self.modelPath = modelPath
        self.dimension = dimension
        self.maxLength = maxLength
        self.tokenizer = SimpleTokenizer(maxLength: maxLength)
    }

    public func embed(texts: [String]) async throws -> [[Float]] {
        // Load model if needed
        if mlModel == nil {
            try await loadModel()
        }

        guard let model = mlModel else {
            throw EmbeddingError.modelNotLoaded
        }

        // Process each text
        var embeddings: [[Float]] = []
        for text in texts {
            let embedding = try await generateEmbedding(for: text, using: model)
            embeddings.append(embedding)
        }

        return embeddings
    }

    /// Load the CoreML model
    private func loadModel() async throws {
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw EmbeddingError.modelNotLoaded
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU // Use Neural Engine if available
            mlModel = try MLModel(contentsOf: modelPath, configuration: config)
        } catch {
            throw EmbeddingError.embeddingFailed("Failed to load CoreML model: \(error.localizedDescription)")
        }
    }

    /// Generate embedding for a single text
    private func generateEmbedding(for text: String, using model: MLModel) async throws -> [Float] {
        // Tokenize the input text
        let (inputIDs, attentionMask) = tokenizer.tokenize(text)

        // Create MLMultiArray inputs
        let inputIDsArray = try MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32)
        let attentionMaskArray = try MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32)

        // Fill arrays
        for i in 0..<maxLength {
            inputIDsArray[i] = NSNumber(value: inputIDs[i])
            attentionMaskArray[i] = NSNumber(value: attentionMask[i])
        }

        // Create input feature provider
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIDsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
        ])

        // Run inference
        let output = try await model.prediction(from: inputFeatures)

        // Extract the last_hidden_state output
        guard let outputFeature = output.featureValue(for: "var_2815"),
              let outputArray = outputFeature.multiArrayValue else {
            throw EmbeddingError.embeddingFailed("Failed to extract model output")
        }

        // Perform mean pooling over the sequence dimension
        // Output shape: [1, max_length, hidden_size] -> [hidden_size]
        let embedding = try meanPooling(
            hiddenStates: outputArray,
            attentionMask: attentionMask
        )

        // Normalize the embedding vector
        return normalize(embedding)
    }

    /// Perform mean pooling on hidden states using attention mask
    private func meanPooling(
        hiddenStates: MLMultiArray,
        attentionMask: [Int32]
    ) throws -> [Float] {
        let batchSize = hiddenStates.shape[0].intValue
        let seqLength = hiddenStates.shape[1].intValue
        let hiddenSize = hiddenStates.shape[2].intValue

        guard batchSize == 1, seqLength == maxLength, hiddenSize == dimension else {
            throw EmbeddingError.embeddingFailed("Unexpected output shape")
        }

        // Sum embeddings for non-padded tokens
        var sumEmbedding = [Float](repeating: 0.0, count: dimension)
        var tokenCount: Float = 0.0

        for seqIdx in 0..<seqLength {
            let mask = Float(attentionMask[seqIdx])
            if mask > 0 {
                tokenCount += 1.0
                for dimIdx in 0..<dimension {
                    let linearIndex = seqIdx * dimension + dimIdx
                    let value = hiddenStates[linearIndex].floatValue
                    sumEmbedding[dimIdx] += value * mask
                }
            }
        }

        // Average by number of non-padded tokens
        guard tokenCount > 0 else {
            throw EmbeddingError.embeddingFailed("No valid tokens found")
        }

        return sumEmbedding.map { $0 / tokenCount }
    }

    /// Normalize embedding vector to unit length
    private func normalize(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}

// MARK: - Simple Tokenizer

/// Simple BPE-like tokenizer for prototype
/// Note: This is a simplified version. For production, use a proper tokenizer
private struct SimpleTokenizer {
    let maxLength: Int

    /// Tokenize text into input_ids and attention_mask
    /// Returns: (input_ids, attention_mask)
    func tokenize(_ text: String) -> ([Int32], [Int32]) {
        var inputIDs = [Int32](repeating: 0, count: maxLength)
        var attentionMask = [Int32](repeating: 0, count: maxLength)

        // Special tokens
        let clsToken: Int32 = 101  // [CLS]
        let sepToken: Int32 = 102  // [SEP]
        // Pad token (0) is default in array initialization

        // Start with [CLS]
        inputIDs[0] = clsToken
        attentionMask[0] = 1

        // Tokenize text (simple whitespace split)
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var position = 1
        for word in words {
            guard position < maxLength - 1 else { break }

            // Simple hash-based token ID (consistent hashing)
            let tokenID = Int32(abs(word.hashValue % 30000) + 1000)
            inputIDs[position] = tokenID
            attentionMask[position] = 1
            position += 1
        }

        // Add [SEP] token
        if position < maxLength {
            inputIDs[position] = sepToken
            attentionMask[position] = 1
        }

        // Remaining positions are already padded with 0s

        return (inputIDs, attentionMask)
    }
}

#else
// Non-Apple platforms: Use mock implementation
public final class LocalEmbedder: Embedder {
    private let dimension: Int
    private let maxLength: Int

    public var embeddingDimension: Int {
        get async { dimension }
    }

    public var maxSequenceLength: Int {
        get async { maxLength }
    }

    public init(modelPath: URL, dimension: Int = 384, maxLength: Int = 128) {
        self.dimension = dimension
        self.maxLength = maxLength
    }

    public func embed(texts: [String]) async throws -> [[Float]] {
        throw EmbeddingError.embeddingFailed("CoreML not available on this platform")
    }
}
#endif
