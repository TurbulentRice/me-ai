# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal AI is a privacy-first, on-device iOS LLM assistant with local RAG capabilities. All inference, embeddings, and data storage happen entirely on-device with no cloud dependencies. The project uses Swift Package Manager with XcodeGen for a VSCode/Cursor-first development workflow.

## Build Commands

### Primary Development Commands

```bash
# Build the iOS app
./scripts/build.sh

# Run all tests
./scripts/test.sh

# Generate/regenerate Xcode project (after changing Package.swift or project.yml)
./scripts/generate_xcode.sh

# Download ML models (Phi-3 Mini + embeddings)
./scripts/download_models.sh
```

### Swift Package Manager Commands

```bash
# Build the core library only
swift build

# Run tests via SPM (faster for unit tests)
swift test

# Resolve dependencies after Package.swift changes
swift package resolve

# Clean build artifacts
rm -rf .build DerivedData *.xcodeproj
```

### Running on Simulator/Device

```bash
# Open in Xcode (for simulator/device deployment)
open PersonalLLM.xcodeproj

# Build for specific simulator
xcodebuild build -project PersonalLLM.xcodeproj -scheme PersonalLLM \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Architecture

### Layer Structure

The codebase follows a clean layered architecture:

1. **UI Layer** (`App/PersonalLLM/`)
   - SwiftUI views: `ChatView`, `DocumentsView`, `SettingsView`
   - ViewModels: `ChatViewModel`, `DocumentsViewModel`, `SettingsViewModel`
   - `AppCoordinator`: Dependency injection container that wires up all components

2. **Core Engine** (`Sources/PersonalLLMCore/Engine/`)
   - `RAGEngine`: Main orchestrator for retrieval-augmented generation
   - `DocumentIngestion`: Handles file parsing and chunking pipeline
   - `DocumentManager`: CRUD operations for documents
   - `TextChunker`: Semantic chunking with overlap

3. **Storage Layer** (`Sources/PersonalLLMCore/Storage/`)
   - `VectorDatabase` protocol + `SQLiteVectorDB` implementation
   - `Models.swift`: Core data structures (`Document`, `Chunk`, `SearchResult`)
   - SQLite with cosine similarity search for vector retrieval

4. **Model Runtime** (`Sources/PersonalLLMCore/ModelRuntime/`)
   - `LocalLLM` protocol: Abstraction for LLM inference
   - `Embedder` protocol: Abstraction for embedding generation
   - `MockLLM` and `MockEmbedder`: Testing implementations
   - `LocalEmbedder`: Real CoreML embedding model (Phase MVP-2 complete)
   - Real LLM integration pending (see Phase MVP-3 guide)

5. **Privacy Layer** (`Sources/PersonalLLMCore/Privacy/`)
   - `DatabaseEncryption`: AES-GCM encryption for chunk text
   - `KeychainManager`: iOS Keychain for encryption key storage
   - `EncryptedVectorDatabase`: Wrapper that encrypts/decrypts transparently

### Dependency Flow

```
PersonalLLMApp.swift (entry point)
    ↓
AppCoordinator (DI container)
    ↓
Creates: RAGEngine, DocumentManager, Database, Embedder, LLM
    ↓
RAGEngine orchestrates: Embedder → VectorDB → LLM
    ↓
ViewModels consume: RAGEngine, DocumentManager
    ↓
Views display: Streaming responses, citations, documents
```

### Key Protocols

All abstractions are protocol-based for testability and platform portability:

- `LocalLLM`: `load()`, `generate()` (streaming), `unload()`
- `Embedder`: `embed(text:)`, `embed(texts:)`
- `VectorDatabase`: `insertDocument()`, `insertChunk()`, `searchSimilar()`

## Project Structure

```
personal-ai/
├── Package.swift              # SPM manifest - dependencies and targets
├── project.yml                # XcodeGen config - generates .xcodeproj
├── App/PersonalLLM/          # iOS app target (SwiftUI)
├── Sources/PersonalLLMCore/  # Shared library (all business logic)
│   ├── Storage/              # Database, models, schema
│   ├── Engine/               # RAG orchestration, chunking, ingestion
│   ├── ModelRuntime/         # LLM and embedder abstractions
│   ├── Privacy/              # Encryption and keychain
│   └── UI/                   # Reusable SwiftUI components
├── Tests/PersonalLLMCoreTests/
│   ├── unit/                 # Unit tests for individual components
│   └── integration/          # End-to-end RAG pipeline tests
├── Models/                    # ML models (gitignored, see download script)
│   ├── Phi3Mini/             # Phi-3.1-mini-128k-Q4_K_M.gguf (2.2GB)
│   └── Embeddings/           # all-MiniLM-L6-v2 CoreML model (43MB)
├── scripts/                   # Build automation
└── docs/                      # Architecture and implementation guides
```

## Development Workflow

### VSCode/Cursor-First Approach

This project is designed for VSCode/Cursor development with minimal Xcode usage:

1. **Edit code** in VSCode/Cursor (full Swift LSP support)
2. **Build from CLI** with `./scripts/build.sh`
3. **Run tests** with `./scripts/test.sh`
4. **Only use Xcode** for simulator/device deployment and debugging

The `.xcodeproj` file is gitignored and generated from `project.yml` via XcodeGen. This keeps version control clean and avoids merge conflicts.

### Adding New Files

1. Create the Swift file in `Sources/PersonalLLMCore/<Module>/`
2. Edit in VSCode/Cursor
3. Run `./scripts/generate_xcode.sh` (only if adding to app target)
4. Build with `./scripts/build.sh`

Swift Package Manager auto-discovers files in `Sources/`, so most files don't require `project.yml` changes.

### Adding Dependencies

Edit `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/user/repo.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "PersonalLLMCore",
        dependencies: [
            .product(name: "ProductName", package: "repo"),
        ]
    ),
]
```

Then:
```bash
swift package resolve
./scripts/generate_xcode.sh
```

## Current Implementation Status

### Completed Phases (P0 Prototype)

- ✅ **Phase 0**: Project setup, SPM structure, XcodeGen integration
- ✅ **Phase 1**: Storage layer (SQLite vector DB with 11 tests)
- ✅ **Phase 2**: Model runtime abstractions (13 tests)
- ✅ **Phase 3**: RAG engine implementation (14 tests)
- ✅ **Phase 4**: UI layer (SwiftUI chat interface)
- ✅ **Phase 5**: Privacy & security (AES-GCM encryption, 10 tests)
- ✅ **Phase 6**: Testing & documentation (59 total tests passing)

### MVP Integration (In Progress)

- ✅ **Phase MVP-1**: Model download (Phi-3 Mini + embeddings)
- ✅ **Phase MVP-2**: Real embedder integration (CoreML, working)
- 🚧 **Phase MVP-3**: Real LLM integration (60% complete, 3-4 hours remaining)
  - See `docs/PHASE_MVP3_COMPLETION_GUIDE.md` for implementation steps
  - Currently using `MockLLM` for chat generation
  - Plan: Integrate llama.cpp via SwiftLlama wrapper
- ⏳ **Phase MVP-4**: ViewModel & UI polish
- ⏳ **Phase MVP-5**: Testing & deployment

## RAG Pipeline Flow

Understanding the full RAG flow is critical when modifying components:

### Document Ingestion

1. User selects file → `DocumentManager.ingestDocument(url:)`
2. `DocumentIngestion` extracts text (plain text, PDF, or image via Vision)
3. `TextChunker.chunk(text:)` splits into semantic chunks (~512 tokens, overlap)
4. `Embedder.embed(texts:)` generates vector for each chunk
5. `VectorDatabase.insertDocument()` + `insertChunk()` stores in SQLite

### Query & Response

1. User asks question → `RAGEngine.answer(query:)`
2. `Embedder.embed(text: query)` generates query vector
3. `VectorDatabase.searchSimilar()` finds top-k chunks via cosine similarity
4. `RAGEngine.buildPrompt()` constructs context with citations
5. `LocalLLM.generate()` streams tokens back to UI
6. `ChatView` displays response with inline citations

### Key Files for RAG Flow

- Entry point: `App/PersonalLLM/PersonalLLMApp.swift` (DI setup)
- Ingestion: `Sources/PersonalLLMCore/Engine/DocumentIngestion.swift`
- Chunking: `Sources/PersonalLLMCore/Engine/TextChunker.swift`
- Retrieval: `Sources/PersonalLLMCore/Storage/VectorDatabase.swift`
- Generation: `Sources/PersonalLLMCore/Engine/RAGEngine.swift`
- Streaming UI: `App/PersonalLLM/Views/ChatView.swift`

## Testing Strategy

### Test Organization

- `Tests/PersonalLLMCoreTests/unit/` - Component isolation tests
- `Tests/PersonalLLMCoreTests/integration/` - Multi-component tests
- `Tests/PersonalLLMCoreTests/Privacy/` - Encryption tests

### Running Specific Tests

```bash
# All tests
swift test

# Specific test class
swift test --filter VectorDatabaseTests

# Specific test method
swift test --filter VectorDatabaseTests/testInsertAndSearch
```

### Test Patterns

- Use `MockLLM` and `MockEmbedder` with `deterministicMode: true` for reproducibility
- Vector DB tests use temporary SQLite files (`:memory:` or temp directory)
- Integration tests follow full pipeline: ingest → query → verify response
- Privacy tests verify encryption roundtrip and key isolation

## Model Information

### Default Models

| Model | Size | Quantization | Purpose | Status |
|-------|------|--------------|---------|--------|
| Phi-3.1-mini-128k-instruct | 2.2GB | Q4_K_M | Chat generation | Downloaded, not integrated |
| all-MiniLM-L6-v2 | 43MB | CoreML | Text embeddings | Integrated ✅ |

### Model Locations

- **Embeddings**: `Models/Embeddings/embeddings.mlpackage` (bundled with app)
- **LLM**: `Models/Phi3Mini/phi3-mini-128k-q4.gguf` (downloaded, not yet loaded)

### Model Loading Pattern

```swift
// Real model with graceful fallback
let embedder: Embedder
if let modelURL = Bundle.main.url(forResource: "embeddings", withExtension: "mlpackage") {
    embedder = LocalEmbedder(modelPath: modelURL, dimension: 384, maxLength: 128)
} else {
    embedder = MockEmbedder(dimension: 384, maxLength: 512, deterministicMode: true)
}
```

## Privacy & Security

All operations are local-first with encryption at rest:

- **No cloud calls**: Zero external network requests
- **No telemetry**: No analytics or tracking
- **Encrypted storage**: Chunk text encrypted with AES-GCM-256
- **Keychain integration**: Encryption keys stored in iOS Keychain (never in code)
- **User control**: Full data deletion via `PrivacyManager.secureDelete()`

When working with sensitive data:
- Never log chunk text or embeddings in production
- Use `EncryptedVectorDatabase` wrapper for automatic encryption
- Test encryption roundtrips in `EncryptionTests.swift`

## Common Development Tasks

### Running the app in simulator

```bash
./scripts/generate_xcode.sh  # If project doesn't exist
open PersonalLLM.xcodeproj
# In Xcode: Cmd+R to run
```

### Debugging build failures

```bash
# Clean everything
rm -rf .build DerivedData *.xcodeproj

# Regenerate and rebuild
./scripts/generate_xcode.sh
./scripts/build.sh
```

### Adding a new component

Example: Adding a new chunking strategy

1. Create `Sources/PersonalLLMCore/Engine/CustomChunker.swift`
2. Implement `TextChunker` protocol (or create new protocol)
3. Add unit tests in `Tests/PersonalLLMCoreTests/unit/CustomChunkerTests.swift`
4. Wire up in `DocumentIngestion` if replacing default
5. Build and test: `./scripts/build.sh && ./scripts/test.sh`

### Changing the database schema

1. Update `Sources/PersonalLLMCore/Storage/DatabaseSchema.swift`
2. Increment schema version in `SQLiteVectorDB.init()`
3. Add migration logic in `createTables()` method
4. Update integration tests to verify migration
5. Document breaking changes in schema comments

## Important Notes

- **Platform Requirements**: iOS 17+, macOS 14+ (for CoreML and SwiftUI features)
- **Xcode Version**: 15+ required (Swift 5.9+)
- **Device Recommendations**: iPhone with A15+ chip for acceptable LLM performance
- **Context Length**: Use 2048-4096 tokens on mobile (not full 128k context)
- **Performance Target**: 5-15 tokens/sec generation, <2s query latency
- **App Size**: ~500MB including models (Phi-3 Mini dominates size)

## Documentation

Key documentation files:

- `docs/VSCODE_WORKFLOW.md` - Detailed VSCode/Cursor development guide
- `docs/PROTOTYPE.md` - Original design document and architecture
- `docs/PROTOTYPE_IMPLEMENTATION_PLAN.md` - Phased implementation roadmap
- `docs/PHASE_MVP3_COMPLETION_GUIDE.md` - Next steps for LLM integration
- `docs/UI_CORE_INTEGRATION.md` - MVP progress tracking
- `docs/PERFORMANCE.md` - Benchmarks and optimization notes

## Git Workflow

- `.xcodeproj` is gitignored (regenerate with XcodeGen)
- `Models/` directory is gitignored (download with script)
- Commit source files, tests, and `project.yml` changes
- Use conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`
