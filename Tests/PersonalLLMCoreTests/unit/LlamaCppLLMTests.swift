import XCTest
@testable import PersonalLLMCore

final class LlamaCppLLMTests: XCTestCase {
    var llm: LlamaCppLLM!
    var modelPath: URL!

    override func setUp() async throws {
        llm = LlamaCppLLM()

        // Try to find the real model
        let possiblePaths = [
            // Development path
            FileManager.default.currentDirectoryPath + "/Models/Phi3Mini/phi3-mini-128k-q4.gguf",
            // Absolute path
            "/Users/sean/Dev/personal-ai/Models/Phi3Mini/phi3-mini-128k-q4.gguf"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                modelPath = URL(fileURLWithPath: path)
                break
            }
        }
    }

    override func tearDown() async throws {
        try? await llm.unload()
        llm = nil
        modelPath = nil
    }

    func testInitialization() throws {
        XCTAssertNotNil(llm, "LlamaCppLLM should initialize")
    }

    func testIsLoadedInitially() async throws {
        let isLoaded = await llm.isLoaded
        XCTAssertFalse(isLoaded, "Model should not be loaded initially")
    }

    func testModelInfoInitially() async throws {
        let modelInfo = await llm.modelInfo
        XCTAssertNil(modelInfo, "Model info should be nil before loading")
    }

    func testModelLoadingWithValidPath() async throws {
        guard let modelPath = modelPath else {
            throw XCTSkip("Model file not found - skipping load test. Run ./scripts/download_models.sh to download the model.")
        }

        // Load the model
        try await llm.load(modelPath: modelPath, config: .phi3Mini)

        // Verify loaded state
        let isLoaded = await llm.isLoaded
        XCTAssertTrue(isLoaded, "Model should be loaded after load() call")

        // Verify model info
        let modelInfo = await llm.modelInfo
        XCTAssertNotNil(modelInfo, "Model info should be available after loading")
        XCTAssertEqual(modelInfo?.architecture, "phi3", "Architecture should be phi3")
        XCTAssertEqual(modelInfo?.quantization, "Q4_K_M", "Quantization should be Q4_K_M")
    }

    func testModelLoadingWithInvalidPath() async throws {
        let invalidPath = URL(fileURLWithPath: "/nonexistent/model.gguf")

        do {
            try await llm.load(modelPath: invalidPath, config: .phi3Mini)
            XCTFail("Loading invalid path should throw an error")
        } catch {
            // Expected to throw
            XCTAssertTrue(error is ModelRuntimeError, "Error should be ModelRuntimeError")
        }
    }

    func testGeneration() async throws {
        guard let modelPath = modelPath else {
            throw XCTSkip("Model file not found - skipping generation test")
        }

        // Load model
        try await llm.load(modelPath: modelPath, config: .phi3Mini)

        // Generate response
        let stream = try await llm.generate(
            prompt: "What is 2+2?",
            stopSequences: [],
            maxTokens: 50,
            temperature: 0.7
        )

        // Collect tokens
        var response = ""
        var tokenCount = 0
        for await token in stream {
            response += token
            tokenCount += 1
        }

        // Verify response
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
        XCTAssertGreaterThan(tokenCount, 0, "Should generate at least one token")
        print("Generated response: \(response)")
    }

    func testGenerationWithoutLoadedModel() async throws {
        // Try to generate without loading
        do {
            _ = try await llm.generate(
                prompt: "Test",
                stopSequences: [],
                maxTokens: 10,
                temperature: 0.7
            )
            XCTFail("Generation without loaded model should throw")
        } catch {
            XCTAssertTrue(error is ModelRuntimeError, "Should throw ModelRuntimeError")
            if let runtimeError = error as? ModelRuntimeError {
                if case .modelNotLoaded = runtimeError {
                    // Expected error
                } else {
                    XCTFail("Should throw modelNotLoaded error")
                }
            }
        }
    }

    func testMaxTokensLimit() async throws {
        guard let modelPath = modelPath else {
            throw XCTSkip("Model file not found - skipping max tokens test")
        }

        try await llm.load(modelPath: modelPath, config: .phi3Mini)

        let maxTokens = 5
        let stream = try await llm.generate(
            prompt: "Count to 100",
            stopSequences: [],
            maxTokens: maxTokens,
            temperature: 0.7
        )

        var tokenCount = 0
        for await _ in stream {
            tokenCount += 1
        }

        XCTAssertLessThanOrEqual(tokenCount, maxTokens, "Should not exceed max tokens")
    }

    func testUnload() async throws {
        guard let modelPath = modelPath else {
            throw XCTSkip("Model file not found - skipping unload test")
        }

        // Load then unload
        try await llm.load(modelPath: modelPath, config: .phi3Mini)
        var isLoaded = await llm.isLoaded
        XCTAssertTrue(isLoaded, "Model should be loaded")

        try await llm.unload()
        isLoaded = await llm.isLoaded
        XCTAssertFalse(isLoaded, "Model should be unloaded")

        let modelInfo = await llm.modelInfo
        XCTAssertNil(modelInfo, "Model info should be nil after unload")
    }
}
