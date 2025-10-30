import Foundation

// MARK: - LocalLLM Protocol

/// Protocol for local LLM inference operations
public protocol LocalLLM: Sendable {
    /// Load a model from disk
    /// - Parameters:
    ///   - modelPath: URL to the model file or directory
    ///   - config: Configuration for model inference
    func load(modelPath: URL, config: LLMConfig) async throws

    /// Generate text completion with streaming
    /// - Parameters:
    ///   - prompt: Input prompt for generation
    ///   - stopSequences: Sequences that terminate generation
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Sampling temperature (0.0 = greedy, higher = more random)
    /// - Returns: AsyncStream of generated tokens
    func generate(
        prompt: String,
        stopSequences: [String],
        maxTokens: Int,
        temperature: Float
    ) async throws -> AsyncStream<String>

    /// Unload the model from memory
    func unload() async throws

    /// Check if a model is currently loaded
    var isLoaded: Bool { get async }

    /// Get model information
    var modelInfo: ModelInfo? { get async }
}

// MARK: - LLM Configuration

/// Configuration for LLM inference
public struct LLMConfig: Sendable {
    /// Maximum context length (input + output tokens)
    public let contextLength: Int

    /// Batch size for processing
    public let batchSize: Int

    /// Default sampling temperature
    public let temperature: Float

    /// Top-p nucleus sampling parameter
    public let topP: Float

    /// Top-k sampling parameter
    public let topK: Int

    /// Number of threads for inference
    public let numThreads: Int

    public init(
        contextLength: Int = 8192,
        batchSize: Int = 1,
        temperature: Float = 0.7,
        topP: Float = 0.95,
        topK: Int = 50,
        numThreads: Int = 4
    ) {
        self.contextLength = contextLength
        self.batchSize = batchSize
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.numThreads = numThreads
    }

    /// Default configuration for Phi-3 Mini 128k
    public static let phi3Mini = LLMConfig(
        contextLength: 8192,
        batchSize: 1,
        temperature: 0.7,
        topP: 0.95,
        topK: 50,
        numThreads: 4
    )

    /// Default configuration for Gemma 2B
    public static let gemma2B = LLMConfig(
        contextLength: 4096,
        batchSize: 1,
        temperature: 0.7,
        topP: 0.95,
        topK: 40,
        numThreads: 4
    )
}

// MARK: - Model Information

/// Information about a loaded model
public struct ModelInfo: Sendable {
    /// Model name
    public let name: String

    /// Model architecture (e.g., "phi3", "gemma")
    public let architecture: String

    /// Number of parameters
    public let numParameters: Int64

    /// Quantization scheme (e.g., "q4", "q8", "fp16")
    public let quantization: String

    /// Model version
    public let version: String

    public init(
        name: String,
        architecture: String,
        numParameters: Int64,
        quantization: String,
        version: String
    ) {
        self.name = name
        self.architecture = architecture
        self.numParameters = numParameters
        self.quantization = quantization
        self.version = version
    }
}

// MARK: - Model Runtime Errors

/// Errors that can occur during model operations
public enum ModelRuntimeError: Error, LocalizedError {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case generationFailed(String)
    case modelNotLoaded
    case invalidConfiguration(String)
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Model not found at path: \(path)"
        case .modelLoadFailed(let message):
            return "Failed to load model: \(message)"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .modelNotLoaded:
            return "No model is currently loaded"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .unsupportedFormat(let format):
            return "Unsupported model format: \(format)"
        }
    }
}

// MARK: - Mock Implementation for Testing

/// Mock implementation of LocalLLM for testing and development
public final class MockLLM: LocalLLM {
    private var _isLoaded = false
    private var _modelInfo: ModelInfo?
    private let delay: Duration

    public var isLoaded: Bool {
        get async { _isLoaded }
    }

    public var modelInfo: ModelInfo? {
        get async { _modelInfo }
    }

    /// Initialize mock LLM with optional response delay
    public init(delay: Duration = .milliseconds(10)) {
        self.delay = delay
    }

    public func load(modelPath: URL, config: LLMConfig) async throws {
        // Simulate model loading
        try await Task.sleep(for: .milliseconds(100))

        _modelInfo = ModelInfo(
            name: "mock-model",
            architecture: "mock",
            numParameters: 3_000_000_000,
            quantization: "q4",
            version: "1.0.0"
        )
        _isLoaded = true
    }

    public func generate(
        prompt: String,
        stopSequences: [String],
        maxTokens: Int,
        temperature: Float
    ) async throws -> AsyncStream<String> {
        guard _isLoaded else {
            throw ModelRuntimeError.modelNotLoaded
        }

        return AsyncStream { continuation in
            Task {
                // Mock response based on prompt
                let response = "This is a mock response to: \(prompt)"
                let words = response.split(separator: " ")

                for word in words {
                    try? await Task.sleep(for: delay)
                    continuation.yield(String(word) + " ")
                }

                continuation.finish()
            }
        }
    }

    public func unload() async throws {
        _isLoaded = false
        _modelInfo = nil
    }
}
