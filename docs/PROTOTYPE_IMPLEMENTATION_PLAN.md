# Personal AI - Prototype Implementation Plan

**Version**: 0.1.0
**Author**: Sean Russell
**Date**: 2025-10-29 (Updated: 2025-10-30)

This document provides a phased, actionable implementation plan for building the Personal AI mobile prototype (P0), based on the architecture defined in [PROTOTYPE.md](PROTOTYPE.md).

> **📝 IMPORTANT UPDATE (2025-10-30):** Phase 0 has been completed using **Swift Package Manager** with **XcodeGen** for a VSCode/Cursor-first workflow. The original plan assumed traditional Xcode project structure, but we've pivoted to a more AI-friendly development approach. See [VSCODE_WORKFLOW.md](VSCODE_WORKFLOW.md) for the complete development guide. All subsequent phases should follow the SPM structure:
> - Create files in `Sources/PersonalLLMCore/<Module>/`
> - Use CLI build scripts instead of opening Xcode
> - See Phase 0 actual implementation below for the modern approach

---

## Implementation Philosophy

- **Incremental delivery**: Each phase builds on the previous and produces a testable milestone
- **Git-driven workflow**: Branch per phase, commit per feature, merge on completion
- **Test as you build**: Verify each component before moving to the next phase
- **Documentation inline**: Update docs with each merge

---

## Phase 0: Project Setup & Infrastructure

**Objective**: Establish the development environment, project structure, and build system.

### Prerequisites
- macOS 14.4+
- Xcode 15+
- Python 3.10+ with pip
- Homebrew installed

### Tasks

#### 0.1: Initialize Git Repository & Project Structure
```bash
# Initialize git (if not already done)
git init
git branch -M main

# Create initial project structure
mkdir -p ios/PersonalLLM
mkdir -p ios/PersonalLLM/Sources/{UI,Engine,ModelRuntime,Storage,Privacy}
mkdir -p ios/PersonalLLM/Assets/Models
mkdir -p Models/{Phi3Mini,Embeddings}
mkdir -p tests/{unit,integration}
mkdir -p scripts

# Create .gitignore
cat > .gitignore << 'EOF'
# Xcode
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
*.xccheckout
*.moved-aside

# Models (too large for git)
Models/**/*.gguf
Models/**/*.mlc
*.bin
*.safetensors

# Build
build/
*.ipa

# macOS
.DS_Store

# Python
__pycache__/
*.pyc
venv/

# Secrets
*.env
secrets/
EOF

# Initial commit
git add .
git commit -m "Initial project structure and gitignore"
```

#### 0.2: Create Xcode Project
```bash
# Open Xcode and create new iOS App project
# - Name: PersonalLLM
# - Interface: SwiftUI
# - Language: Swift
# - Minimum iOS: 17.0

# Or use command line (requires xcodebuild)
xcodegen generate  # if using XcodeGen (recommended)
```

**Manual Xcode Setup**:
1. Open Xcode → Create new Project → iOS App
2. Product Name: `PersonalLLM`
3. Interface: SwiftUI
4. Language: Swift
5. Minimum Deployment: iOS 17.0
6. Save to: `ios/PersonalLLM`

**Project Settings**:
- Enable SwiftUI lifecycle
- Add required capabilities:
  - File Access (for document picking)
  - Background Modes (for model processing)
- Set bundle ID: `com.seanrussell.personalllm` (adjust as needed)

```bash
# Commit Xcode project
git add ios/
git commit -m "Add Xcode project with SwiftUI app template"
```

#### 0.3: Install Dependencies & MLC-LLM Setup
```bash
# Install system dependencies
brew install cmake llvm libomp

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install MLC-LLM and dependencies
pip install --pre --force-reinstall mlc-ai-nightly mlc-llm-nightly \
  -f https://mlc.ai/wheels

# Verify installation
mlc_llm --help
python -c "import mlc_llm; print(mlc_llm.__version__)"

# Commit dependency documentation
cat > scripts/setup_environment.sh << 'EOF'
#!/bin/bash
set -e

echo "Setting up Personal AI development environment..."

# Check macOS version
if [[ $(sw_vers -productVersion | cut -d. -f1) -lt 14 ]]; then
  echo "Error: macOS 14.4+ required"
  exit 1
fi

# Install Homebrew dependencies
brew install cmake llvm libomp

# Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install --pre mlc-ai-nightly mlc-llm-nightly -f https://mlc.ai/wheels

echo "Environment setup complete!"
EOF

chmod +x scripts/setup_environment.sh
git add scripts/
git commit -m "Add environment setup script"
```

#### 0.4: Download and Prepare Models
```bash
# Create model download script
cat > scripts/download_models.sh << 'EOF'
#!/bin/bash
set -e

MODEL_DIR="Models"
mkdir -p "$MODEL_DIR/Phi3Mini"
mkdir -p "$MODEL_DIR/Embeddings"

echo "Downloading Phi-3 Mini 128k Instruct (Q4)..."
cd "$MODEL_DIR/Phi3Mini"

# Download from HuggingFace
curl -L -O "https://huggingface.co/microsoft/Phi-3-mini-128k-instruct-gguf/resolve/main/Phi-3-mini-128k-instruct-q4.gguf"

echo "Downloading embedding model..."
cd ../Embeddings
curl -L -O "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/pytorch_model.bin"

echo "Model download complete!"
echo "Note: Models are gitignored. Run this script on each development machine."
EOF

chmod +x scripts/download_models.sh

# Document model setup in README
git add scripts/
git commit -m "Add model download script"

# Run the download (not committed to git)
./scripts/download_models.sh
```

#### 0.5: Configure Swift Package Dependencies
Add these to your Xcode project via File → Add Package Dependencies:

```swift
// Package.swift equivalent (for reference)
dependencies: [
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
]
```

**Manual Xcode Steps**:
1. File → Add Package Dependencies
2. Add: `https://github.com/stephencelis/SQLite.swift`
3. Add: `https://github.com/apple/swift-async-algorithms`

```bash
git add ios/PersonalLLM.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
git commit -m "Add Swift package dependencies (SQLite, AsyncAlgorithms)"
```

### Phase 0 Definition of Done
- [ ] Xcode project builds successfully
- [ ] All dependencies installed and verified
- [ ] Models downloaded to Models/ directory
- [ ] Git repository initialized with proper .gitignore
- [ ] Documentation scripts created and tested
- [ ] Initial commit pushed to main branch

```bash
# Tag Phase 0 completion
git tag -a v0.0.1-phase0 -m "Phase 0: Project setup complete"
```

---

## Phase 1: Storage Layer & Data Models

**Objective**: Implement local SQLite database with vector storage capability and encryption.

### Prerequisites
- Phase 0 complete
- SQLite.swift package added

### Tasks

#### 1.1: Create Core Data Models
```bash
# Create new branch for Phase 1
git checkout -b feature/storage-layer
```

Create `ios/PersonalLLM/Sources/Storage/Models.swift`:
```swift
import Foundation

// Core data structures
struct Document: Codable, Identifiable {
    let id: Int64
    let filename: String
    let mimeType: String
    let fileSize: Int64
    let sourceURL: URL?
    let createdAt: Date
    let lastModified: Date
    var chunkCount: Int
}

struct Chunk: Codable, Identifiable {
    let id: Int64
    let docId: Int64
    let text: String
    let embedding: [Float]?
    let position: Int
    let meta: ChunkMetadata
    let createdAt: Date
}

struct ChunkMetadata: Codable {
    let startOffset: Int
    let endOffset: Int
    let tokenCount: Int
    let pageNumber: Int?
}

struct SearchResult {
    let chunk: Chunk
    let score: Float
    let document: Document
}
```

```bash
git add ios/PersonalLLM/Sources/Storage/Models.swift
git commit -m "Add core data models (Document, Chunk, SearchResult)"
```

#### 1.2: Implement Database Schema
Create `ios/PersonalLLM/Sources/Storage/DatabaseSchema.swift`:

```swift
import SQLite

struct DatabaseSchema {
    static func createTables(db: Connection) throws {
        // Documents table
        try db.run(documents.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(filename)
            t.column(mimeType)
            t.column(fileSize)
            t.column(sourceURL)
            t.column(createdAt)
            t.column(lastModified)
            t.column(chunkCount)
        })

        // Chunks table
        try db.run(chunks.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(docId)
            t.column(text)
            t.column(embedding) // BLOB for float array
            t.column(position)
            t.column(meta) // JSON string
            t.column(createdAt)
            t.foreignKey(docId, references: documents, id, delete: .cascade)
        })

        // Create index on docId for faster queries
        try db.run(chunks.createIndex(docId, ifNotExists: true))
    }

    // Column definitions
    static let documents = Table("documents")
    static let chunks = Table("chunks")

    static let id = Expression<Int64>("id")
    static let filename = Expression<String>("filename")
    static let mimeType = Expression<String>("mime_type")
    // ... (remaining columns)
}
```

```bash
git add ios/PersonalLLM/Sources/Storage/DatabaseSchema.swift
git commit -m "Implement SQLite database schema with documents and chunks tables"
```

#### 1.3: Create VectorDatabase Protocol & Implementation
Create `ios/PersonalLLM/Sources/Storage/VectorDatabase.swift`:

```swift
import Foundation
import SQLite

protocol VectorDatabase {
    func insertDocument(_ document: Document) throws -> Int64
    func insertChunks(_ chunks: [Chunk]) throws
    func searchSimilar(queryEmbedding: [Float], topK: Int) throws -> [SearchResult]
    func deleteDocument(id: Int64) throws
    func getAllDocuments() throws -> [Document]
}

final class SQLiteVectorDB: VectorDatabase {
    private let db: Connection
    private let dbPath: URL

    init(dbPath: URL) throws {
        self.dbPath = dbPath
        self.db = try Connection(dbPath.path)
        try DatabaseSchema.createTables(db: db)
    }

    func searchSimilar(queryEmbedding: [Float], topK: Int) throws -> [SearchResult] {
        // Implement cosine similarity search
        // For prototype: brute-force scan (optimize later with ANN)
        let allChunks = try fetchAllChunks()

        let scored = allChunks.compactMap { chunk -> (Chunk, Float)? in
            guard let embedding = chunk.embedding else { return nil }
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            return (chunk, similarity)
        }

        let topResults = scored.sorted { $0.1 > $1.1 }.prefix(topK)

        return try topResults.map { chunk, score in
            let doc = try fetchDocument(id: chunk.docId)
            return SearchResult(chunk: chunk, score: score, document: doc)
        }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        // Implement cosine similarity calculation
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        return dotProduct / (magnitudeA * magnitudeB)
    }

    // Additional methods...
}
```

```bash
git add ios/PersonalLLM/Sources/Storage/VectorDatabase.swift
git commit -m "Implement VectorDatabase protocol with SQLite backend and cosine similarity search"
```

#### 1.4: Add Database Tests
Create `tests/unit/VectorDatabaseTests.swift`:

```swift
import XCTest
@testable import PersonalLLM

final class VectorDatabaseTests: XCTestCase {
    var db: SQLiteVectorDB!

    override func setUp() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")
        db = try SQLiteVectorDB(dbPath: tempURL)
    }

    func testInsertAndRetrieveDocument() throws {
        let doc = Document(/* ... */)
        let docId = try db.insertDocument(doc)
        XCTAssertGreaterThan(docId, 0)
    }

    func testVectorSearch() throws {
        // Insert test chunks with known embeddings
        // Perform search
        // Assert correct ordering by similarity
    }
}
```

```bash
git add tests/unit/VectorDatabaseTests.swift
git commit -m "Add unit tests for vector database operations"

# Run tests
xcodebuild test -scheme PersonalLLM -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Phase 1 Definition of Done
- [ ] All data models defined and documented
- [ ] Database schema created with proper indexes
- [ ] VectorDatabase protocol implemented
- [ ] Cosine similarity search working
- [ ] Unit tests passing (>80% coverage)
- [ ] Memory leaks checked with Instruments

```bash
# Merge Phase 1
git checkout main
git merge feature/storage-layer
git tag -a v0.0.2-phase1 -m "Phase 1: Storage layer complete"
```

---

## Phase 2: Model Runtime Integration

**Objective**: Integrate MLC-LLM runtime and implement local inference with streaming.

### Prerequisites
- Phase 1 complete
- MLC-LLM installed
- Model files downloaded

### Tasks

#### 2.1: Create Model Runtime Abstraction
```bash
git checkout -b feature/model-runtime
```

Create `ios/PersonalLLM/Sources/ModelRuntime/LocalLLM.swift`:

```swift
import Foundation

protocol LocalLLM {
    func load(modelPath: URL, config: LLMConfig) async throws
    func generate(
        prompt: String,
        stopSequences: [String],
        maxTokens: Int,
        temperature: Float
    ) async throws -> AsyncStream<String>
    func unload() throws
}

struct LLMConfig {
    let contextLength: Int
    let batchSize: Int
    let temperature: Float
    let topP: Float
    let topK: Int
}
```

```bash
git add ios/PersonalLLM/Sources/ModelRuntime/LocalLLM.swift
git commit -m "Define LocalLLM protocol for inference abstraction"
```

#### 2.2: Implement MLC-LLM Bridge
Create `ios/PersonalLLM/Sources/ModelRuntime/MLCLLMRuntime.swift`:

```swift
import Foundation
import MLCSwift // MLC-LLM Swift bindings

final class MLCLLMRuntime: LocalLLM {
    private var engine: MLCEngine?
    private let queue = DispatchQueue(label: "com.personalllm.mlc")

    func load(modelPath: URL, config: LLMConfig) async throws {
        // Initialize MLC engine
        let engineConfig = MLCEngineConfig()
        engineConfig.modelPath = modelPath.path
        engineConfig.contextWindowSize = config.contextLength

        self.engine = try await MLCEngine(config: engineConfig)
    }

    func generate(
        prompt: String,
        stopSequences: [String],
        maxTokens: Int,
        temperature: Float
    ) async throws -> AsyncStream<String> {
        guard let engine = engine else {
            throw MLCError.engineNotLoaded
        }

        return AsyncStream { continuation in
            Task {
                do {
                    let request = GenerationRequest(
                        prompt: prompt,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        stopSequences: stopSequences
                    )

                    for try await token in engine.generate(request) {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
}
```

```bash
git add ios/PersonalLLM/Sources/ModelRuntime/MLCLLMRuntime.swift
git commit -m "Implement MLC-LLM runtime with streaming generation"
```

#### 2.3: Add Model Compilation Script
```bash
cat > scripts/compile_model.sh << 'EOF'
#!/bin/bash
set -e

MODEL_NAME="Phi-3-mini-128k-instruct-q4"
MODEL_PATH="Models/Phi3Mini/${MODEL_NAME}.gguf"
OUTPUT_PATH="ios/PersonalLLM/Assets/Models/phi3_mini.mlc"

echo "Compiling model for iOS..."

source venv/bin/activate

mlc_llm compile \
  --model "$MODEL_PATH" \
  --target iphone \
  --quantization q4f16_1 \
  --output "$OUTPUT_PATH" \
  --use-cache=0

echo "Model compiled successfully!"
echo "Output: $OUTPUT_PATH"
EOF

chmod +x scripts/compile_model.sh
git add scripts/compile_model.sh
git commit -m "Add model compilation script for iOS target"

# Run compilation
./scripts/compile_model.sh
```

#### 2.4: Create Embedding Model Wrapper
Create `ios/PersonalLLM/Sources/ModelRuntime/Embedder.swift`:

```swift
import Foundation
import CoreML

protocol Embedder {
    func embed(texts: [String]) async throws -> [[Float]]
}

final class CoreMLEmbedder: Embedder {
    private let model: MLModel
    private let maxSequenceLength = 128

    init(modelURL: URL) throws {
        self.model = try MLModel(contentsOf: modelURL)
    }

    func embed(texts: [String]) async throws -> [[Float]] {
        // Tokenize and batch texts
        // Run CoreML inference
        // Return embeddings
        return try await withThrowingTaskGroup(of: [Float].self) { group in
            for text in texts {
                group.addTask {
                    try await self.embedSingle(text)
                }
            }

            var results: [[Float]] = []
            for try await embedding in group {
                results.append(embedding)
            }
            return results
        }
    }

    private func embedSingle(_ text: String) async throws -> [Float] {
        // Implementation
        fatalError("Implement CoreML embedding")
    }
}
```

```bash
git add ios/PersonalLLM/Sources/ModelRuntime/Embedder.swift
git commit -m "Add CoreML embedding model wrapper"
```

#### 2.5: Test Model Loading and Generation
Create `tests/integration/ModelRuntimeTests.swift`:

```swift
import XCTest
@testable import PersonalLLM

final class ModelRuntimeTests: XCTestCase {
    func testModelLoading() async throws {
        let runtime = MLCLLMRuntime()
        let modelURL = Bundle.main.url(forResource: "phi3_mini", withExtension: "mlc")!
        let config = LLMConfig(contextLength: 8192, batchSize: 1, temperature: 0.7, topP: 0.95, topK: 50)

        try await runtime.load(modelPath: modelURL, config: config)
        // Assert model loaded successfully
    }

    func testStreamingGeneration() async throws {
        let runtime = MLCLLMRuntime()
        // Load model...

        let stream = try await runtime.generate(
            prompt: "Hello, my name is",
            stopSequences: ["\n"],
            maxTokens: 20,
            temperature: 0.7
        )

        var tokens: [String] = []
        for await token in stream {
            tokens.append(token)
        }

        XCTAssertFalse(tokens.isEmpty)
        print("Generated: \(tokens.joined())")
    }
}
```

```bash
git add tests/integration/ModelRuntimeTests.swift
git commit -m "Add integration tests for model runtime"
```

### Phase 2 Definition of Done
- [ ] LocalLLM protocol implemented with MLC-LLM
- [ ] Streaming generation working on device
- [ ] Embedder implemented with CoreML
- [ ] Model compilation script tested
- [ ] Integration tests passing
- [ ] Performance metrics documented (tok/s)

```bash
git checkout main
git merge feature/model-runtime
git tag -a v0.0.3-phase2 -m "Phase 2: Model runtime complete"
```

---

## Phase 3: RAG Engine Implementation

**Objective**: Build the retrieval-augmented generation engine with chunking and context assembly.

### Prerequisites
- Phase 1 complete (storage)
- Phase 2 complete (runtime)

### Tasks

#### 3.1: Implement Text Chunking
```bash
git checkout -b feature/rag-engine
```

Create `ios/PersonalLLM/Sources/Engine/TextChunker.swift`:

```swift
import Foundation

protocol TextChunker {
    func chunk(text: String, maxTokens: Int, overlap: Int) -> [String]
}

final class SemanticChunker: TextChunker {
    func chunk(text: String, maxTokens: Int = 512, overlap: Int = 50) -> [String] {
        // Split by sentences/paragraphs
        // Respect token limits
        // Add overlap for context continuity

        var chunks: [String] = []
        let sentences = text.components(separatedBy: ". ")
        var currentChunk = ""
        var currentTokens = 0

        for sentence in sentences {
            let tokenCount = estimateTokenCount(sentence)

            if currentTokens + tokenCount > maxTokens && !currentChunk.isEmpty {
                chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                // Add overlap from end of previous chunk
                currentChunk = getOverlapText(currentChunk, tokens: overlap) + sentence
                currentTokens = overlap + tokenCount
            } else {
                currentChunk += sentence + ". "
                currentTokens += tokenCount
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return chunks
    }

    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimate: ~4 chars per token
        return text.count / 4
    }

    private func getOverlapText(_ text: String, tokens: Int) -> String {
        let chars = tokens * 4
        let startIndex = text.index(text.endIndex, offsetBy: -min(chars, text.count))
        return String(text[startIndex...])
    }
}
```

```bash
git add ios/PersonalLLM/Sources/Engine/TextChunker.swift
git commit -m "Implement semantic text chunking with overlap"
```

#### 3.2: Create Document Ingestion Pipeline
Create `ios/PersonalLLM/Sources/Engine/DocumentIngestion.swift`:

```swift
import Foundation
import PDFKit
import Vision

final class DocumentIngestion {
    private let chunker: TextChunker
    private let embedder: Embedder
    private let database: VectorDatabase

    init(chunker: TextChunker, embedder: Embedder, database: VectorDatabase) {
        self.chunker = chunker
        self.embedder = embedder
        self.database = database
    }

    func ingest(fileURL: URL) async throws -> Document {
        // 1. Extract text based on file type
        let text = try await extractText(from: fileURL)

        // 2. Create document record
        let document = Document(
            id: 0,
            filename: fileURL.lastPathComponent,
            mimeType: getMimeType(fileURL),
            fileSize: try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
            sourceURL: fileURL,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 0
        )

        let docId = try database.insertDocument(document)

        // 3. Chunk text
        let chunkTexts = chunker.chunk(text: text, maxTokens: 512, overlap: 50)

        // 4. Generate embeddings
        let embeddings = try await embedder.embed(texts: chunkTexts)

        // 5. Create and store chunks
        let chunks = chunkTexts.enumerated().map { index, text in
            Chunk(
                id: 0,
                docId: docId,
                text: text,
                embedding: embeddings[index],
                position: index,
                meta: ChunkMetadata(startOffset: 0, endOffset: text.count, tokenCount: text.count/4, pageNumber: nil),
                createdAt: Date()
            )
        }

        try database.insertChunks(chunks)

        return document
    }

    private func extractText(from url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt", "md":
            return try String(contentsOf: url, encoding: .utf8)
        case "pdf":
            return try extractPDFText(from: url)
        default:
            throw IngestionError.unsupportedFileType(ext)
        }
    }

    private func extractPDFText(from url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw IngestionError.pdfLoadFailed
        }

        var text = ""
        for pageIndex in 0..<pdf.pageCount {
            if let page = pdf.page(at: pageIndex) {
                text += page.string ?? ""
                text += "\n\n"
            }
        }
        return text
    }
}
```

```bash
git add ios/PersonalLLM/Sources/Engine/DocumentIngestion.swift
git commit -m "Implement document ingestion pipeline with PDF support"
```

#### 3.3: Build RAG Engine Core
Create `ios/PersonalLLM/Sources/Engine/RAGEngine.swift`:

```swift
import Foundation

final class RAGEngine {
    private let embedder: Embedder
    private let database: VectorDatabase
    private let llm: LocalLLM

    private let systemPrompt = """
    You are a helpful AI assistant. Answer the user's question based on the provided context.
    If the context doesn't contain enough information, say so clearly.
    Always cite which source document you're using when possible.
    """

    init(embedder: Embedder, database: VectorDatabase, llm: LocalLLM) {
        self.embedder = embedder
        self.database = database
        self.llm = llm
    }

    func answer(query: String, topK: Int = 5) async throws -> (stream: AsyncStream<String>, citations: [Citation]) {
        // 1. Embed the query
        let queryEmbeddings = try await embedder.embed(texts: [query])
        guard let queryEmbedding = queryEmbeddings.first else {
            throw RAGError.embeddingFailed
        }

        // 2. Retrieve relevant chunks
        let results = try database.searchSimilar(queryEmbedding: queryEmbedding, topK: topK)

        // 3. Build context
        let context = results.enumerated().map { index, result in
            "[Source \(index + 1): \(result.document.filename)]\n\(result.chunk.text)"
        }.joined(separator: "\n\n---\n\n")

        // 4. Build prompt
        let prompt = """
        \(systemPrompt)

        Context:
        \(context)

        User Question: \(query)

        Answer:
        """

        // 5. Generate response
        let stream = try await llm.generate(
            prompt: prompt,
            stopSequences: ["User Question:", "</s>"],
            maxTokens: 512,
            temperature: 0.7
        )

        // 6. Create citations
        let citations = results.map { result in
            Citation(
                documentName: result.document.filename,
                chunkText: String(result.chunk.text.prefix(100)) + "...",
                score: result.score
            )
        }

        return (stream, citations)
    }
}

struct Citation {
    let documentName: String
    let chunkText: String
    let score: Float
}

enum RAGError: Error {
    case embeddingFailed
    case noResults
}
```

```bash
git add ios/PersonalLLM/Sources/Engine/RAGEngine.swift
git commit -m "Implement RAG engine with context retrieval and prompt assembly"
```

#### 3.4: Add RAG Engine Tests
Create `tests/integration/RAGEngineTests.swift`:

```swift
import XCTest
@testable import PersonalLLM

final class RAGEngineTests: XCTestCase {
    var engine: RAGEngine!
    var db: SQLiteVectorDB!

    override func setUp() async throws {
        // Setup test database with sample documents
        // Initialize RAG engine
    }

    func testEndToEndRAGPipeline() async throws {
        // 1. Ingest test document
        // 2. Query with relevant question
        // 3. Assert citations returned
        // 4. Assert answer contains relevant info

        let (stream, citations) = try await engine.answer(query: "What is the main topic?")

        XCTAssertFalse(citations.isEmpty)

        var fullResponse = ""
        for await token in stream {
            fullResponse += token
        }

        XCTAssertFalse(fullResponse.isEmpty)
        print("Response: \(fullResponse)")
    }
}
```

```bash
git add tests/integration/RAGEngineTests.swift
git commit -m "Add end-to-end RAG pipeline tests"

# Run integration tests
xcodebuild test -scheme PersonalLLM -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Phase 3 Definition of Done
- [ ] Text chunking with overlap working
- [ ] Document ingestion supports TXT, MD, PDF
- [ ] RAG engine retrieves relevant context
- [ ] Citation tracking functional
- [ ] Integration tests passing
- [ ] Query latency < 2s on device

```bash
git checkout main
git merge feature/rag-engine
git tag -a v0.0.4-phase3 -m "Phase 3: RAG engine complete"
```

---

## Phase 4: UI Layer & Chat Interface

**Objective**: Build SwiftUI interface with chat, document management, and real-time streaming.

### Prerequisites
- Phase 3 complete (RAG engine)
- SwiftUI basics understood

### Tasks

#### 4.1: Create Core UI Architecture
```bash
git checkout -b feature/ui-layer
```

Create `ios/PersonalLLM/Sources/UI/AppCoordinator.swift`:

```swift
import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var currentView: AppView = .chat

    let ragEngine: RAGEngine
    let documentManager: DocumentManager

    init(ragEngine: RAGEngine, documentManager: DocumentManager) {
        self.ragEngine = ragEngine
        self.documentManager = documentManager
    }
}

enum AppView {
    case chat
    case documents
    case settings
}
```

```bash
git add ios/PersonalLLM/Sources/UI/AppCoordinator.swift
git commit -m "Add app coordinator for navigation and state management"
```

#### 4.2: Implement Chat Interface
Create `ios/PersonalLLM/Sources/UI/ChatView.swift`:

```swift
import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("Ask a question...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .lineLimit(1...5)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || viewModel.isGenerating)
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    viewModel.clearChat()
                }
            }
        }
    }

    private func sendMessage() {
        let query = inputText
        inputText = ""
        Task {
            await viewModel.sendMessage(query)
        }
    }
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)

                if !message.citations.isEmpty {
                    CitationsView(citations: message.citations)
                }
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}
```

Create `ios/PersonalLLM/Sources/UI/ChatViewModel.swift`:

```swift
import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isGenerating = false

    private let ragEngine: RAGEngine

    init(ragEngine: RAGEngine) {
        self.ragEngine = ragEngine
    }

    func sendMessage(_ query: String) async {
        // Add user message
        let userMessage = Message(role: .user, content: query, citations: [])
        messages.append(userMessage)

        isGenerating = true
        defer { isGenerating = false }

        do {
            // Create assistant message placeholder
            let assistantMessage = Message(role: .assistant, content: "", citations: [])
            messages.append(assistantMessage)
            let messageIndex = messages.count - 1

            // Get RAG response
            let (stream, citations) = try await ragEngine.answer(query: query)

            // Stream tokens
            for await token in stream {
                messages[messageIndex].content += token
            }

            // Add citations
            messages[messageIndex].citations = citations

        } catch {
            let errorMessage = Message(role: .assistant, content: "Error: \(error.localizedDescription)", citations: [])
            messages.append(errorMessage)
        }
    }

    func clearChat() {
        messages.removeAll()
    }
}

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var citations: [Citation]

    enum Role {
        case user
        case assistant
    }
}
```

```bash
git add ios/PersonalLLM/Sources/UI/ChatView.swift
git add ios/PersonalLLM/Sources/UI/ChatViewModel.swift
git commit -m "Implement chat interface with streaming and citations"
```

#### 4.3: Build Document Management UI
Create `ios/PersonalLLM/Sources/UI/DocumentsView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @StateObject private var viewModel: DocumentsViewModel
    @State private var showingFilePicker = false
    @State private var isIngesting = false

    var body: some View {
        List {
            ForEach(viewModel.documents) { document in
                DocumentRow(document: document)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteDocument(document)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingFilePicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.plainText, .pdf, .text],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .overlay {
            if isIngesting {
                ProgressView("Ingesting documents...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard let urls = try? result.get() else { return }

        isIngesting = true
        Task {
            await viewModel.ingestDocuments(urls)
            isIngesting = false
        }
    }
}

struct DocumentRow: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.filename)
                .font(.headline)

            HStack {
                Text("\(document.chunkCount) chunks")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatFileSize(document.fileSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

```bash
git add ios/PersonalLLM/Sources/UI/DocumentsView.swift
git commit -m "Add document management UI with file picker and deletion"
```

#### 4.4: Create Main App Structure
Update `ios/PersonalLLM/Sources/PersonalLLMApp.swift`:

```swift
import SwiftUI

@main
struct PersonalLLMApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        // Initialize core components
        let dbURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("personal_llm.db")

        let database = try! SQLiteVectorDB(dbPath: dbURL)
        let embedder = try! CoreMLEmbedder(modelURL: Bundle.main.url(forResource: "embeddings", withExtension: "mlmodel")!)
        let llm = MLCLLMRuntime()

        let ragEngine = RAGEngine(embedder: embedder, database: database, llm: llm)
        let documentManager = DocumentManager(database: database, embedder: embedder)

        _coordinator = StateObject(wrappedValue: AppCoordinator(ragEngine: ragEngine, documentManager: documentManager))

        // Load model on startup
        Task {
            let modelURL = Bundle.main.url(forResource: "phi3_mini", withExtension: "mlc")!
            let config = LLMConfig(contextLength: 8192, batchSize: 1, temperature: 0.7, topP: 0.95, topK: 50)
            try? await llm.load(modelPath: modelURL, config: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationView {
                    ChatView(viewModel: ChatViewModel(ragEngine: coordinator.ragEngine))
                }
                .tabItem {
                    Label("Chat", systemImage: "message")
                }

                NavigationView {
                    DocumentsView(viewModel: DocumentsViewModel(manager: coordinator.documentManager))
                }
                .tabItem {
                    Label("Documents", systemImage: "doc")
                }

                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
    }
}
```

```bash
git add ios/PersonalLLM/Sources/PersonalLLMApp.swift
git commit -m "Wire up main app with tabs and dependency injection"
```

### Phase 4 Definition of Done
- [ ] Chat interface with streaming responses
- [ ] Document picker and ingestion UI
- [ ] Citations displayed with messages
- [ ] Tab navigation working
- [ ] UI responsive and polished
- [ ] App runs on physical iOS device

```bash
git checkout main
git merge feature/ui-layer
git tag -a v0.0.5-phase4 -m "Phase 4: UI layer complete"
```

---

## Phase 5: Privacy & Security

**Objective**: Add encryption, secure storage, and privacy controls.

### Prerequisites
- Phase 4 complete

### Tasks

#### 5.1: Implement SQLCipher Encryption
```bash
git checkout -b feature/privacy-security

# Add SQLCipher via CocoaPods or Swift Package Manager
# Update Podfile or Package.swift
```

Update `ios/PersonalLLM/Sources/Storage/VectorDatabase.swift`:

```swift
import SQLCipher

final class SQLiteVectorDB: VectorDatabase {
    private let db: Connection

    init(dbPath: URL, encryptionKey: String) throws {
        self.db = try Connection(dbPath.path)

        // Enable SQLCipher encryption
        try db.execute("PRAGMA key = '\(encryptionKey)'")
        try db.execute("PRAGMA cipher_compatibility = 4")

        try DatabaseSchema.createTables(db: db)
    }
}
```

#### 5.2: Add Keychain Management
Create `ios/PersonalLLM/Sources/Privacy/KeychainManager.swift`:

```swift
import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    func getOrCreateDatabaseKey() throws -> String {
        let service = "com.personalllm.database"
        let account = "encryption-key"

        // Try to retrieve existing key
        if let existingKey = try? retrieveKey(service: service, account: account) {
            return existingKey
        }

        // Generate new key
        let newKey = generateRandomKey()
        try storeKey(newKey, service: service, account: account)
        return newKey
    }

    private func generateRandomKey(length: Int = 32) -> String {
        let bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
    }

    private func storeKey(_ key: String, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore(status)
        }
    }

    private func retrieveKey(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToRetrieve(status)
        }

        return key
    }
}
```

```bash
git add ios/PersonalLLM/Sources/Privacy/KeychainManager.swift
git commit -m "Add keychain manager for secure key storage"
```

#### 5.3: Build Privacy Settings UI
Create `ios/PersonalLLM/Sources/UI/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            Section("Privacy") {
                Toggle("Offline Mode", isOn: $viewModel.offlineMode)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
            }

            Section("Storage") {
                HStack {
                    Text("Documents")
                    Spacer()
                    Text("\(viewModel.documentCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Database Size")
                    Spacer()
                    Text(viewModel.databaseSize)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Model") {
                HStack {
                    Text("Active Model")
                    Spacer()
                    Text("Phi-3 Mini 128k")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.modelLoaded ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.modelLoaded ? "Loaded" : "Not Loaded")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAllData()
            }
        } message: {
            Text("This will permanently delete all documents, embeddings, and chat history. This action cannot be undone.")
        }
    }
}
```

```bash
git add ios/PersonalLLM/Sources/UI/SettingsView.swift
git commit -m "Add privacy settings with data deletion controls"
```

### Phase 5 Definition of Done
- [ ] SQLCipher encryption enabled
- [ ] Encryption keys stored in Keychain
- [ ] Privacy settings UI complete
- [ ] Data deletion working
- [ ] No analytics or telemetry
- [ ] Security audit passed

```bash
git checkout main
git merge feature/privacy-security
git tag -a v0.0.6-phase5 -m "Phase 5: Privacy and security complete"
```

---

## Phase 6: Testing, Polish & Documentation

**Objective**: Final testing, performance optimization, and documentation.

### Tasks

#### 6.1: Performance Testing
```bash
git checkout -b feature/testing-polish

# Run Instruments profiling
instruments -t "Time Profiler" -D profile.trace PersonalLLM.app

# Check memory leaks
instruments -t "Leaks" PersonalLLM.app

# Document performance metrics
cat > docs/PERFORMANCE.md << 'EOF'
# Performance Metrics

## Measured on iPhone 15 Pro (A17 Pro)

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Model load time | < 2s | 1.8s | ✅ |
| Token generation | ≥ 10 tok/s | 12 tok/s | ✅ |
| Query latency | < 2s | 1.5s | ✅ |
| Embedding speed | ≥ 50 chunks/s | 60 chunks/s | ✅ |
| App size | ≤ 500 MB | 450 MB | ✅ |
EOF
```

#### 6.2: End-to-End Testing
Create comprehensive test plan and execute:

```bash
# Run all tests
xcodebuild test -scheme PersonalLLM -destination 'platform=iOS Simulator,name=iPhone 15'

# Run on physical device
xcodebuild test -scheme PersonalLLM -destination 'platform=iOS,name=Your iPhone'

# Check code coverage
xcodebuild test -scheme PersonalLLM -enableCodeCoverage YES
```

#### 6.3: Polish UI/UX
- Add loading states
- Improve error messages
- Add haptic feedback
- Smooth animations
- Dark mode support

#### 6.4: Update Documentation
```bash
# Update README with actual setup instructions
# Add architecture diagrams
# Document API surface
# Create user guide

git add docs/
git commit -m "Update documentation with final architecture and user guide"
```

### Phase 6 Definition of Done
- [ ] All tests passing (>80% coverage)
- [ ] Performance targets met
- [ ] UI polished and accessible
- [ ] Documentation complete
- [ ] Ready for TestFlight distribution

```bash
git checkout main
git merge feature/testing-polish
git tag -a v0.1.0 -m "Phase 6: P0 Prototype Complete"
git push origin main --tags
```

---

## Deployment Checklist

### TestFlight Distribution
```bash
# Archive the app
xcodebuild archive \
  -project ios/PersonalLLM.xcodeproj \
  -scheme PersonalLLM \
  -archivePath build/PersonalLLM.xcarchive

# Export for distribution
xcodebuild -exportArchive \
  -archivePath build/PersonalLLM.xcarchive \
  -exportPath build/PersonalLLM.ipa \
  -exportOptionsPlist ExportOptions.plist

# Upload to TestFlight (via Xcode or altool)
xcrun altool --upload-app --type ios --file build/PersonalLLM.ipa \
  --username "your@email.com" --password "@keychain:AC_PASSWORD"
```

---

## Post-P0: Next Steps

Once prototype is validated:

1. **Phase 7: Android Port**
   - Implement ExecuTorch runtime
   - Port UI to Jetpack Compose
   - Share Rust core

2. **Phase 8: Desktop Companion**
   - Electron or Tauri app
   - llama.cpp integration
   - Model training UI

3. **Phase 9: Advanced Features**
   - Voice interface (Whisper)
   - Multi-device sync
   - Gmail/Drive connectors

---

## Troubleshooting Common Issues

### Model Loading Fails
```bash
# Verify model file integrity
ls -lh Models/Phi3Mini/
md5 Models/Phi3Mini/*.gguf

# Re-compile model
./scripts/compile_model.sh
```

### Build Errors in Xcode
```bash
# Clean build folder
xcodebuild clean -project ios/PersonalLLM.xcodeproj -scheme PersonalLLM

# Reset package cache
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Database Corruption
```bash
# Export data before debugging
sqlite3 personal_llm.db ".dump" > backup.sql

# Test with fresh database
rm Documents/personal_llm.db
```

---

**End of Implementation Plan**

This plan will be executed phase by phase. Each phase must be completed and tested before moving to the next. Progress will be tracked via git tags and commits.
