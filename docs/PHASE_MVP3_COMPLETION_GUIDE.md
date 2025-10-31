# Phase MVP-3 Completion Guide: LLM Integration

**Created**: 2025-10-30
**Status**: In Progress (60% complete)
**Estimated Time Remaining**: 3-4 hours

---

## Overview

This guide provides detailed instructions for completing Phase MVP-3: integrating a real LLM (Phi-3 Mini) using llama.cpp for on-device inference.

---

## Current Status

### ✅ Completed

1. **Model Downloaded**
   - Phi-3.1-mini-128k-instruct-Q4_K_M.gguf (2.2GB)
   - Location: `Models/Phi3Mini/phi3-mini-128k-q4.gguf`
   - Verified: GGUF magic bytes confirmed

2. **Research & Decision**
   - Evaluated MLC-LLM vs llama.cpp
   - Chose **llama.cpp** approach (better GGUF support)
   - Identified SwiftLlama as the best Swift wrapper

3. **Architecture**
   - LocalLLM protocol already defined
   - MockLLM working as reference implementation
   - Clear integration points identified

### 🚧 In Progress

4. **LLM Implementation** (60% complete)
   - SwiftLlama research done
   - API patterns identified
   - Needs: Full implementation + testing

### ⏳ Remaining

5. **Integration & Testing**
   - App integration
   - End-to-end testing
   - Performance benchmarking

---

## Implementation Approach

### Option A: SwiftLlama (Recommended)

**Pros:**
- ✅ Clean Swift API
- ✅ Actively maintained (2025)
- ✅ Swift Package Manager support
- ✅ Async/await and AsyncSequence support
- ✅ Comprehensive examples

**Cons:**
- Requires macOS 15.0+ (may need conditional compilation for older versions)

**Package:** `https://github.com/ShenghaiWang/SwiftLlama.git`

### Option B: llama.cpp Direct (Alternative)

**Pros:**
- Lower-level control
- No version constraints

**Cons:**
- More complex C++ interop
- Manual memory management
- More boilerplate code

---

## Step-by-Step Implementation

### Step 1: Add SwiftLlama Dependency

**File:** `Package.swift`

```swift
// Update platforms
platforms: [
    .iOS(.v17),
    .macOS("15.0")  // Required for SwiftLlama
],

// Add dependency
dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/ShenghaiWang/SwiftLlama.git", from: "0.4.0"),
],

// Add to target
.target(
    name: "PersonalLLMCore",
    dependencies: [
        .product(name: "SQLite", package: "SQLite.swift"),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "SwiftLlama", package: "SwiftLlama"),
    ],
    // ...
)
```

### Step 2: Implement LlamaCppLLM

**File:** `Sources/PersonalLLMCore/ModelRuntime/LlamaCppLLM.swift`

```swift
import Foundation
import SwiftLlama

/// Real LLM implementation using SwiftLlama (llama.cpp wrapper)
public final class LlamaCppLLM: LocalLLM {
    private var llama: SwiftLlama?
    private var _modelInfo: ModelInfo?

    public var isLoaded: Bool {
        get async { llama != nil }
    }

    public var modelInfo: ModelInfo? {
        get async { _modelInfo }
    }

    public init() {}

    public func load(modelPath: URL, config: LLMConfig) async throws {
        // Initialize SwiftLlama
        do {
            self.llama = try SwiftLlama(modelPath: modelPath.path)
        } catch {
            throw ModelRuntimeError.modelLoadFailed(error.localizedDescription)
        }

        // Store model info
        self._modelInfo = ModelInfo(
            name: modelPath.lastPathComponent,
            architecture: "phi3",
            numParameters: 3_800_000_000,  // 3.8B
            quantization: "Q4_K_M",
            version: "3.1-mini-128k"
        )

        print("✅ SwiftLlama model loaded")
        print("   Model: \(modelPath.lastPathComponent)")
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
                    // SwiftLlama returns AsyncSequence of tokens
                    for try await token in await llama.start(for: prompt) {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    print("Generation error: \(error)")
                    continuation.finish()
                }
            }
        }
    }

    public func unload() async throws {
        llama = nil
        _modelInfo = nil
        print("✅ SwiftLlama model unloaded")
    }
}
```

**Notes:**
- SwiftLlama's `start(for:)` returns `AsyncSequence<String, Error>`
- Each yielded value is a token (word/subword)
- Stop sequences and max tokens may need custom handling

### Step 3: Update App to Use Real LLM

**File:** `App/PersonalLLM/PersonalLLMApp.swift`

```swift
init() {
    // ... existing database and embedder setup ...

    // Create LLM - try real model, fall back to mock
    let llm: LocalLLM
    let modelPath = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("../../Models/Phi3Mini/phi3-mini-128k-q4.gguf")

    if FileManager.default.fileExists(atPath: modelPath.path) {
        llm = LlamaCppLLM()
        Task {
            do {
                try await llm.load(modelPath: modelPath, config: .phi3Mini)
                print("✅ Using real Phi-3 LLM")
            } catch {
                print("⚠️  Failed to load real LLM: \(error)")
            }
        }
    } else {
        llm = MockLLM(delay: .milliseconds(50))
        print("⚠️  Phi-3 model not found, using MockLLM")
    }

    // ... rest of initialization ...
}
```

### Step 4: Handle Model Path in iOS

Since iOS apps can't directly access `Models/` directory, you have two options:

**Option A: Bundle model with app** (Large app size)
```swift
if let modelURL = Bundle.main.url(forResource: "phi3-mini-128k-q4", withExtension: "gguf") {
    // Use bundled model
}
```

**Option B: Download on first launch** (Recommended)
```swift
let modelsDir = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Models")

let modelPath = modelsDir.appendingPathComponent("phi3-mini-128k-q4.gguf")

if !FileManager.default.fileExists(atPath: modelPath.path) {
    // Show download UI
    // Download from GitHub releases or similar
}
```

---

## Testing Strategy

### Unit Tests

**File:** `Tests/PersonalLLMCoreTests/LlamaCppLLMTests.swift`

```swift
import XCTest
@testable import PersonalLLMCore

final class LlamaCppLLMTests: XCTestCase {
    var llm: LlamaCppLLM!
    var modelPath: URL!

    override func setUp() async throws {
        llm = LlamaCppLLM()
        // Use test model or mock path
        modelPath = URL(fileURLWithPath: "/path/to/test/model.gguf")
    }

    func testModelLoading() async throws {
        try await llm.load(modelPath: modelPath, config: .phi3Mini)
        let isLoaded = await llm.isLoaded
        XCTAssertTrue(isLoaded)
    }

    func testGeneration() async throws {
        try await llm.load(modelPath: modelPath, config: .phi3Mini)

        let stream = try await llm.generate(
            prompt: "What is 2+2?",
            stopSequences: [],
            maxTokens: 50,
            temperature: 0.7
        )

        var response = ""
        for await token in stream {
            response += token
        }

        XCTAssertFalse(response.isEmpty)
    }
}
```

### Integration Tests

Test end-to-end flow:
1. Load model
2. Ingest document
3. Ask question
4. Verify streaming response
5. Check citations

---

## Performance Considerations

### Expected Performance (Phi-3 Mini Q4 on iPhone)

| Metric | Target | Notes |
|--------|--------|-------|
| Model load time | < 5s | First load |
| Token generation | 5-15 tok/s | Depends on device |
| Memory usage | ~2-4 GB | Model + context |
| First token latency | < 1s | TTFT |

### Optimization Tips

1. **Quantization**: Q4_K_M is good balance
2. **Context length**: Use 2048-4096 for mobile (not full 128k)
3. **Batch size**: Keep at 1 for streaming
4. **Threads**: 4 threads on most devices

---

## Troubleshooting

### Issue: "Model file too large"
**Solution**: Use quantized model (Q4 recommended)

### Issue: "Out of memory"
**Solution**: Reduce context length in config

### Issue: "Slow inference"
**Solution**:
- Check device (A15+ chip recommended)
- Reduce context length
- Use lower quantization (Q4 vs Q8)

### Issue: "SwiftLlama build fails"
**Solution**:
- Ensure macOS 15.0+ requirement
- Check Xcode version (17+)
- Clear DerivedData

---

## Alternative: Hybrid Approach

For MVP, consider a hybrid:

1. **Phase 1**: Use MockLLM with realistic delays
2. **Phase 2**: Add real embedder (✅ DONE)
3. **Phase 3**: Add real LLM for specific use cases
4. **Phase 4**: Full LLM integration

This allows faster iteration while building toward full on-device inference.

---

## API Reference

### SwiftLlama Basic Usage

```swift
// Initialize
let llama = try SwiftLlama(modelPath: "/path/to/model.gguf")

// Async/await (complete response)
let response: String = try await llama.start(for: "Hello, how are you?")

// AsyncSequence (streaming)
for try await token in await llama.start(for: "Tell me a story") {
    print(token, terminator: "")
}

// Combine publisher
await llama.start(for: prompt)
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { token in print(token) }
    )
    .store(in: &cancellables)
```

### Advanced Configuration

SwiftLlama supports additional parameters (check latest docs):
- Temperature
- Top-p
- Top-k
- Repeat penalty
- Context size

---

## Next Steps After Completion

1. **Performance Profiling**
   - Use Instruments to profile
   - Optimize hot paths
   - Monitor memory usage

2. **UI Polish**
   - Add loading indicators
   - Show generation progress
   - Handle errors gracefully

3. **Device Testing**
   - Test on physical iPhone
   - Test on different iOS versions
   - Test with various prompts

4. **Documentation**
   - Update API_REFERENCE.md
   - Add usage examples
   - Document performance characteristics

---

## Resources

- **SwiftLlama GitHub**: https://github.com/ShenghaiWang/SwiftLlama
- **llama.cpp**: https://github.com/ggerganov/llama.cpp
- **Phi-3 Model Card**: https://huggingface.co/microsoft/Phi-3-mini-128k-instruct
- **GGUF Format**: https://github.com/ggerganov/ggml/blob/master/docs/gguf.md

---

## Estimated Timeline

| Task | Time | Priority |
|------|------|----------|
| Add SwiftLlama dependency | 30 min | High |
| Implement LlamaCppLLM | 2 hours | High |
| App integration | 1 hour | High |
| Testing | 1-2 hours | Medium |
| Optimization | 1-2 hours | Low |

**Total**: 3-4 hours for core implementation, 5-7 hours with testing and optimization.

---

## Success Criteria

- [ ] SwiftLlama dependency added
- [ ] LlamaCppLLM implementation complete
- [ ] Model loads successfully
- [ ] Streaming generation works
- [ ] End-to-end RAG pipeline functional
- [ ] Performance acceptable (5+ tok/s)
- [ ] Tests passing
- [ ] Documented

---

**Version**: 1.0
**Last Updated**: 2025-10-30
**Author**: Claude (with Sean Russell)
