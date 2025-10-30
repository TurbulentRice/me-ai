import Foundation
import Combine
import PersonalLLMCore

/// View model for settings screen
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var offlineMode = true // Always offline for P0
    @Published var modelLoaded = false
    @Published var documentCount = 0
    @Published var databaseSize = "Unknown"

    private let manager: DocumentManager
    private let llm: LocalLLM

    init(manager: DocumentManager, llm: LocalLLM) {
        self.manager = manager
        self.llm = llm
        loadStats()
    }

    /// Load statistics
    func loadStats() {
        Task {
            // Check model status
            modelLoaded = await llm.isLoaded

            // Get document count
            do {
                documentCount = try manager.getDocumentCount()
            } catch {
                print("Failed to get document count: \(error)")
            }

            // Get database size
            do {
                let size = try manager.getDatabaseSize()
                databaseSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } catch {
                databaseSize = "Unknown"
            }
        }
    }

    /// Delete all data
    func deleteAllData() {
        do {
            try manager.deleteAllDocuments()
            loadStats()
        } catch {
            print("Failed to delete all data: \(error)")
        }
    }

    /// Get app version
    func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    /// Get model info
    func getModelInfo() async -> String {
        guard await llm.isLoaded else {
            return "Not loaded"
        }

        do {
            guard let info = try await llm.modelInfo else {
                return "Unknown"
            }
            return "\(info.name) - \(info.numParameters)M params"
        } catch {
            return "Unknown"
        }
    }
}
