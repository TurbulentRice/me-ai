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

        // Create embedder
        let embedder = MockEmbedder(dimension: 384, maxLength: 512, deterministicMode: true)

        // Create LLM
        let llm = MockLLM(delay: .milliseconds(50))

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
            let modelURL = URL(fileURLWithPath: "/mock/model/phi3-mini")
            try? await llm.load(modelPath: modelURL, config: .phi3Mini)
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
