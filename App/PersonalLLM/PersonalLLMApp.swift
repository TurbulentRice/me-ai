import SwiftUI
import PersonalLLMCore

@main
struct PersonalLLMApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        // Initialize core components
        let dbURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("personal_llm.db")

        // Create database
        let database = try! SQLiteVectorDB(dbPath: dbURL)

        // Create embedder - try real model, fall back to mock
        let embedder: Embedder
        if let modelURL = Bundle.main.url(forResource: "embeddings", withExtension: "mlpackage") {
            embedder = LocalEmbedder(modelPath: modelURL, dimension: 384, maxLength: 128)
            print("✅ Using real CoreML embedder")
        } else {
            embedder = MockEmbedder(dimension: 384, maxLength: 512, deterministicMode: true)
            print("⚠️  CoreML model not found, using MockEmbedder")
        }

        // Create LLM - try bundled model first, then Documents, fall back to mock
        let llm: LocalLLM
        var modelPath: URL?

        // Try to find the model in this order:
        // 1. Bundled with app (for production)
        if let bundledModelPath = Bundle.main.url(forResource: "phi3-mini-128k-q4", withExtension: "gguf") {
            modelPath = bundledModelPath
            print("✅ Found bundled Phi-3 model")
        }
        // 2. In development Models directory (for development)
        else {
            let devModelsPath = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Models/Phi3Mini/phi3-mini-128k-q4.gguf")

            if FileManager.default.fileExists(atPath: devModelsPath.path) {
                modelPath = devModelsPath
                print("✅ Found development Phi-3 model")
            }
        }

        // Initialize LLM based on what we found
        if let modelPath = modelPath {
            llm = LlamaCppLLM()
            print("✅ Using real Phi-3 LLM")
            print("   Model path: \(modelPath.path)")
        } else {
            llm = MockLLM(delay: .milliseconds(50))
            print("⚠️  Phi-3 model not found")
            print("⚠️  Using MockLLM instead")
        }

        // Create chunker
        let chunker = SemanticChunker()

        // Create ingestion pipeline
        let ingestion = DocumentIngestion(
            chunker: chunker,
            embedder: embedder,
            database: database
        )

        // Create document manager
        let documentManager = DocumentManager(
            database: database,
            ingestion: ingestion
        )

        // Create RAG engine
        let ragEngine = RAGEngine(
            embedder: embedder,
            database: database,
            llm: llm,
            config: .default
        )

        // Create coordinator
        _coordinator = StateObject(wrappedValue: AppCoordinator(
            ragEngine: ragEngine,
            documentManager: documentManager,
            database: database,
            embedder: embedder,
            llm: llm
        ))

        // Load model on startup
        Task {
            do {
                if let modelPath = modelPath {
                    // Load real model
                    try await llm.load(modelPath: modelPath, config: .phi3Mini)
                    print("✅ Phi-3 model loaded successfully")
                } else {
                    // Load mock model
                    let mockModelURL = URL(fileURLWithPath: "/mock/model/phi3-mini")
                    try await llm.load(modelPath: mockModelURL, config: .phi3Mini)
                    print("✅ MockLLM ready")
                }
            } catch {
                print("❌ Failed to load LLM: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                // Chat Tab
                NavigationView {
                    ChatView(viewModel: ChatViewModel(ragEngine: coordinator.ragEngine))
                }
                .tabItem {
                    Label("Chat", systemImage: "message")
                }

                // Documents Tab
                NavigationView {
                    DocumentsView(viewModel: DocumentsViewModel(manager: coordinator.documentManager))
                }
                .tabItem {
                    Label("Documents", systemImage: "doc")
                }

                // Settings Tab
                NavigationView {
                    SettingsView(viewModel: SettingsViewModel(
                        manager: coordinator.documentManager,
                        llm: coordinator.llm
                    ))
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
    }
}
