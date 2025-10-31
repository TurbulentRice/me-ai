import Foundation
import SwiftLlama

/// Real LLM implementation using SwiftLlama (llama.cpp wrapper)
public final class LlamaCppLLM: LocalLLM {
    private var llama: SwiftLlama?
    private var _modelInfo: ModelInfo?
    private var config: LLMConfig?

    public var isLoaded: Bool {
        get async { llama != nil }
    }

    public var modelInfo: ModelInfo? {
        get async { _modelInfo }
    }

    public init() {}

    public func load(modelPath: URL, config: LLMConfig) async throws {
        // Verify model file exists
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelRuntimeError.modelNotFound(modelPath.path)
        }

        // Initialize SwiftLlama
        do {
            self.llama = try SwiftLlama(modelPath: modelPath.path)
            self.config = config
        } catch {
            throw ModelRuntimeError.modelLoadFailed(error.localizedDescription)
        }

        // Store model info
        self._modelInfo = ModelInfo(
            name: modelPath.lastPathComponent,
            architecture: "phi3",
            numParameters: 3_800_000_000,  // 3.8B for Phi-3 Mini
            quantization: "Q4_K_M",
            version: "3.1-mini-128k"
        )

        print("✅ SwiftLlama model loaded")
        print("   Model: \(modelPath.lastPathComponent)")
        print("   Context length: \(config.contextLength)")
    }

    public func generate(
        prompt: String,
        stopSequences: [String],
        maxTokens: Int,
        temperature: Float
    ) async throws -> AsyncStream<String> {
        guard let llama = llama else {
            throw ModelRuntimeError.modelNotLoaded
        }

        return AsyncStream { continuation in
            Task {
                do {
                    // Create Prompt object with proper parameters for Phi-3
                    let llamaPrompt = Prompt(
                        type: .phi,
                        systemPrompt: "You are a helpful AI assistant.",
                        userMessage: prompt,
                        history: []
                    )

                    // Get streaming sequence from SwiftLlama
                    // Use await to cross the actor boundary
                    let sequence: AsyncThrowingStream<String, Error> = await llama.start(for: llamaPrompt)

                    var tokenCount = 0
                    var generatedText = ""

                    for try await token in sequence {
                        // Check max tokens limit
                        guard tokenCount < maxTokens else {
                            break
                        }

                        // Check for stop sequences
                        generatedText += token
                        var shouldStop = false
                        for stopSeq in stopSequences {
                            if generatedText.hasSuffix(stopSeq) {
                                // Remove stop sequence from output
                                let cleanedToken = token.replacingOccurrences(of: stopSeq, with: "")
                                if !cleanedToken.isEmpty {
                                    continuation.yield(cleanedToken)
                                }
                                shouldStop = true
                                break
                            }
                        }

                        if shouldStop {
                            break
                        }

                        continuation.yield(token)
                        tokenCount += 1
                    }

                    continuation.finish()
                } catch {
                    print("❌ Generation error: \(error)")
                    print("   This may indicate the model is not fully loaded or there's a tokenizer issue")
                    continuation.finish()
                }
            }
        }
    }

    public func unload() async throws {
        llama = nil
        _modelInfo = nil
        config = nil
        print("✅ SwiftLlama model unloaded")
    }
}
