# Personal AI

**Personal, On-Device AI Assistant**

Private, local AI — your data, your model, your device.

Personal AI is a mobile-first personal LLM that performs local inference and retrieval-augmented generation (RAG) entirely on-device, with no cloud dependencies.

---

## Overview

Personal AI enables you to:
- Chat with an AI assistant powered by on-device open-source models (Phi-3 Mini, Gemma 2B)
- Index and retrieve your local files for contextual, grounded responses
- Maintain complete privacy — all ML and data storage stay local
- Future expansion to desktop and private server companions

---

## Key Features

- **Local Inference**: Core ML runtime for iOS, ExecuTorch for Android
- **Local RAG**: Embed and search your documents without cloud services
- **Privacy First**: No external network requests, no analytics, no telemetry
- **Encrypted Storage**: AES-XChaCha20 encryption at rest, OS keychain management
- **Streaming Chat**: Real-time responses with source citations
- **Full Control**: Complete data deletion and export capabilities

---

## Quick Start (iOS Prototype)

### Requirements
- macOS 14.4+
- Xcode 15+ (command line tools required, minimal GUI usage)
- VSCode or Cursor (recommended for development)
- iOS 17+ device (A15 chip or newer recommended)
- Python 3.10+ (for model utilities)
- Homebrew package manager

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/TurbulentRice/personal-ai.git
cd personal-ai
```

2. **Install dependencies**
```bash
# Install XcodeGen and build tools
brew install xcodegen xcpretty

# Install Python dependencies and MLC-LLM
./scripts/setup_environment.sh

# Generate Xcode project
./scripts/generate_xcode.sh
```

3. **Prepare models** (optional - can do later)
```bash
./scripts/download_models.sh
```

4. **Build and run**

**Using VSCode/Cursor (recommended):**
```bash
code .  # or: cursor .
# Press Cmd+Shift+B to build
# Or run: ./scripts/build.sh
```

**Using Xcode (for simulator/device):**
```bash
open PersonalLLM.xcodeproj
# Press Cmd+R to run on simulator
```

---

## Development Workflow

This project uses **Swift Package Manager** with **XcodeGen** for a VSCode/Cursor-first development experience:

- **Write code** in VSCode/Cursor with full AI assistance
- **Build from CLI** using `./scripts/build.sh`
- **Run tests** using `./scripts/test.sh`
- **Use Xcode minimally** (only for device deployment and debugging)

See [docs/VSCODE_WORKFLOW.md](docs/VSCODE_WORKFLOW.md) for detailed VSCode development guide.

---

## Architecture

| Layer | Technology |
|-------|-----------|
| **UI** | SwiftUI (iOS) / Jetpack Compose (Android) |
| **Engine** | RAG orchestration, chunking, embedding, retrieval |
| **Vector Store** | SQLite with cosine-similarity search |
| **Runtime** | MLC-LLM (Core ML) for iOS, ExecuTorch for Android |
| **Privacy** | AES/XChaCha20 encryption, OS key storage |

See [docs/SPECIFICATION.md](docs/SPECIFICATION.md) for detailed architecture and API definitions.

---

## Default Models

| Model | Params | Quantization | Context | Purpose |
|-------|--------|--------------|---------|---------|
| Phi-3 Mini 128k Instruct | 3B | Q4_K_M | 8k | Chat inference |
| Gemma 2B Instruct | 2B | Q4 | 4k | Alt chat model |
| MiniLM-E5-Small | ~100M | Int8 | - | Embeddings |

---

## Data Storage

| Location | Purpose |
|----------|---------|
| `Documents/personal_llm.db` | SQLite store for documents, chunks, vectors |
| `Documents/models/` | Local model files (GGUF/Core ML) |
| `Documents/cache/` | Temporary embeddings and logs |

All data encrypted via SQLCipher with keys in iOS Keychain.

---

## Roadmap

| Phase | Focus |
|-------|-------|
| **P0** | Mobile prototype: local RAG + chat (current) |
| **P1** | Shared Rust core + Android build |
| **P2** | Adapter fine-tuning on desktop companion |
| **P3** | Multi-device "Personal Model Hub" with encrypted sync |
| **P4** | Voice, automation, and contextual actions |

---

## Development

### Tech Stack
- SwiftUI + Combine (UI and reactivity)
- MLC-LLM (model inference)
- SQLite / SQLCipher (vector and metadata store)
- Swift Concurrency (async generation streams)
- Vision / PDFKit (text extraction)

### Project Structure
```
personal-ai/
├── Package.swift              # Swift Package Manager manifest
├── project.yml                # XcodeGen configuration
├── App/PersonalLLM/          # iOS app target
├── Sources/PersonalLLMCore/  # Shared library
│   ├── UI/                   # SwiftUI views
│   ├── Engine/               # RAG engine
│   ├── ModelRuntime/         # LLM runtime
│   ├── Storage/              # Vector DB
│   └── Privacy/              # Encryption
├── Tests/                    # Unit & integration tests
├── Models/                   # ML models (gitignored)
└── scripts/                  # Build scripts
```

### Documentation
- [VSCODE_WORKFLOW.md](docs/VSCODE_WORKFLOW.md) - **VSCode/Cursor development guide** (start here!)
- [PROTOTYPE.md](docs/PROTOTYPE.md) - Original design document and system architecture
- [PROTOTYPE_IMPLEMENTATION_PLAN.md](docs/PROTOTYPE_IMPLEMENTATION_PLAN.md) - Phased implementation guide

---

## Privacy & Security

- **No cloud calls**: All processing happens on-device
- **No telemetry**: Zero analytics or tracking
- **Encrypted at rest**: All data encrypted with AES-XChaCha20
- **User control**: Full data deletion and export tools in settings

---

## Contributing

Pull requests and issues are welcome once the project is public.
For now, development is private and directed by Sean Russell.

---

## License

MIT License (to be confirmed before release)

---

**Version**: 0.1.0 - Phase 0 Complete (SPM Structure)
**Author**: Sean Russell
**Updated**: 2025-10-30
