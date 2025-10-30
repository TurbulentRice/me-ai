import SwiftUI
import Combine
import PersonalLLMCore

/// Main application coordinator managing navigation and core dependencies
@MainActor
final class AppCoordinator: ObservableObject {
    @Published var currentView: AppView = .chat

    // Core dependencies
    let ragEngine: RAGEngine
    let documentManager: DocumentManager
    let database: VectorDatabase
    let embedder: Embedder
    let llm: LocalLLM

    init(
        ragEngine: RAGEngine,
        documentManager: DocumentManager,
        database: VectorDatabase,
        embedder: Embedder,
        llm: LocalLLM
    ) {
        self.ragEngine = ragEngine
        self.documentManager = documentManager
        self.database = database
        self.embedder = embedder
        self.llm = llm
    }
}

enum AppView {
    case chat
    case documents
    case settings
}
