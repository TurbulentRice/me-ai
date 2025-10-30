# Personal AI Prototype

1. Objective

Create a mobile-first personal LLM that runs fully on-device, allowing users to:
	•	Chat with an assistant trained on their own unstructured data (files, notes, messages).
	•	Keep all ML, embeddings, and data processing local and private.
	•	Provide a clean, modern UI suitable for public release on app stores.
	•	Maintain architectural extensibility for future desktop or private-server “hub” modes.

⸻

2. Scope — Prototype (P0)

Primary Goals

Goal	Description
Local inference	Run a small quantized (1-3 B) open-source model entirely on the device using a native ML runtime.
Local RAG	Parse, embed, and search a small local corpus (user-selected files).
Privacy first	No cloud calls beyond optional auth (e.g., Gmail later).
Extensible design	Clear engine boundary so the same core can run on desktop later.

Out of Scope (for P0)
	•	Full-scale training or adapter fine-tuning
	•	Cloud sync or multi-device model sharing
	•	Voice, camera, or third-party connectors

⸻

3. Platform Targets

Platform	Runtime	Status
iOS (primary)	Core ML + MLC-LLM	Prototype target
Android (parallel)	ExecuTorch / MLC-LLM Android	Secondary build
Desktop (future)	llama.cpp / GGUF models + Rust core	Deferred to P1


⸻

4. System Architecture

4.1 Layers
	1.	UI Layer – SwiftUI (iOS) / Jetpack Compose (Android)
	2.	Core Engine – handles parsing, embeddings, RAG orchestration
	3.	Model Runtime – platform-native inference (MLC/ExecuTorch)
	4.	Storage – local SQLite DB for documents + embeddings
	5.	Crypto/Privacy – local-only, encrypt-at-rest, no telemetry

4.2 Component Overview

┌──────────────────────┐
│       UI Layer        │  ← SwiftUI / Compose
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│    Core Engine (RAG) │  ← chunking, embed, retrieve, prompt assemble
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│  Vector Store (SQLite)│
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Local LLM Runtime    │  ← MLC-LLM / ExecuTorch
└──────────────────────┘


⸻

5. Data Flow
	1.	Ingest: user selects files → text extracted
	2.	Chunk: split into ~512 token pieces
	3.	Embed: generate vector per chunk
	4.	Store: save {chunk, embedding, meta} in SQLite
	5.	Query:
	•	Embed user question
	•	Retrieve top-k similar chunks
	•	Construct context window
	•	Stream local LLM output with citations

⸻

6. Minimal Interfaces (shared across platforms)

protocol LocalLLM {
    func load(model: URL, config: LLMConfig) throws
    func generate(prompt: String,
                  stop: [String],
                  maxTokens: Int,
                  temperature: Float)
        async throws -> AsyncStream<String>
}

protocol Embedder {
    func embed(texts: [String]) throws -> [[Float]]
}

protocol VectorDB {
    func upsert(_ chunks: [ChunkRow]) throws
    func search(queryEmbedding: [Float], topK: Int) throws -> [ChunkRow]
}

final class RAGEngine {
    init(embedder: Embedder, db: VectorDB, llm: LocalLLM)
    func answer(_ query: String)
        async throws -> (AsyncStream<String>, [Citation])
}


⸻

7. Storage Schema (SQLite)

Table: chunks

Column	Type	Description
id	INTEGER PK	
doc_id	INTEGER	parent document
text	TEXT	chunk text
embedding	BLOB	serialized float vector
meta	JSON	file path, mime, etc.
created_at	DATETIME	insert time


⸻

8. Model Baselines

Role	Model	Params	Quant	Context	Runtime
Chat	Phi-3 Mini (128k Instruct)	3 B	Q4_K_M	8 k	MLC-LLM / ExecuTorch
Alt Chat	Gemma 2B Instruct	2 B	Q4	4 k	same
Embeddings	MiniLM v6 / E5-small	~100 M	Int8	—	Core ML / NNAPI


⸻

9. Performance Targets

Metric	Target
Model load	< 2 s
Generation speed	≥ 10 tok/s
Query latency	< 2 s typical
Index speed	≥ 50 chunks/s
App size	≤ 500 MB (incl. model)


⸻

10. Security & Privacy
	•	All operations local; default “Offline Only” mode.
	•	AES-XChaCha20 encrypted data store.
	•	Keys in OS Keychain / Keystore.
	•	No analytics or telemetry.
	•	User-visible “Data Controls” screen with Delete All.

⸻

11. Deliverables for P0
	•	Mobile app with working local RAG pipeline
	•	Bundled quantized model (Phi-3 Mini Q4)
	•	UI for chat + file ingestion + privacy console
	•	Build scripts and model download instructions
	•	Documentation (README + SPEC.md)

⸻

12. Future Extensions (Post-P0)
	1.	Rust core for cross-platform reuse (iOS / Android / Desktop).
	2.	sqlite-vec / FAISS ANN indexing.
	3.	Gmail / Drive connectors with local cache.
	4.	LoRA adapter training (desktop hub).
	5.	Private mesh sync (WireGuard/Tailscale).
	6.	Voice interface (Whisper tiny int8).

⸻

Version: 0.1 — Mobile Prototype
Author: Sean Russell
Date: (fill on commit)

⸻

Would you like me to generate a matching README.md next, outlining environment setup (MLC-LLM, model download, and iOS build instructions)?