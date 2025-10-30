import Foundation
import Combine

/// View model for privacy and security settings
@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var offlineMode: Bool {
        didSet {
            PrivacyManager.shared.isOfflineModeEnabled = offlineMode
        }
    }

    @Published public var documentCount: Int = 0
    @Published public var chunkCount: Int = 0
    @Published public var databaseSize: String = "0 KB"
    @Published public var modelLoaded: Bool = false
    @Published public var encryptionEnabled: Bool = false

    @Published public var showingError: Bool = false
    @Published public var errorMessage: String = ""

    private let database: VectorDatabase
    private let dbPath: URL

    /// Initialize with database reference
    public init(database: VectorDatabase, dbPath: URL) {
        self.database = database
        self.dbPath = dbPath
        self.offlineMode = PrivacyManager.shared.isOfflineModeEnabled
        self.encryptionEnabled = PrivacyManager.shared.isEncryptionEnabled

        Task {
            await loadSettings()
        }
    }

    // MARK: - Public Methods

    /// Load current settings and statistics
    public func loadSettings() async {
        do {
            let report = try PrivacyManager.shared.generatePrivacyReport(
                database: database,
                dbPath: dbPath
            )

            self.documentCount = report.documentCount
            self.chunkCount = report.chunkCount
            self.databaseSize = report.databaseSizeFormatted
            self.encryptionEnabled = report.encryptionEnabled
            self.offlineMode = report.offlineModeEnabled
        } catch {
            showError("Failed to load settings: \(error.localizedDescription)")
        }
    }

    /// Delete all application data
    public func deleteAllData() {
        Task {
            do {
                // Delete from database
                try PrivacyManager.shared.deleteAllData(database: database)

                // Reset statistics
                documentCount = 0
                chunkCount = 0

                // Note: Keep the database file and encryption key for reuse
                await loadSettings()
            } catch {
                showError("Failed to delete data: \(error.localizedDescription)")
            }
        }
    }

    /// Delete database and reset everything
    public func resetDatabase() {
        Task {
            do {
                // Delete all data first
                try PrivacyManager.shared.deleteAllData(database: database)

                // Delete the database file
                try PrivacyManager.shared.deleteDatabaseFile(at: dbPath)

                // Reset encryption key
                try PrivacyManager.shared.resetEncryption()

                // Reset statistics
                documentCount = 0
                chunkCount = 0
                databaseSize = "0 KB"

                await loadSettings()
            } catch {
                showError("Failed to reset database: \(error.localizedDescription)")
            }
        }
    }

    /// Get security features status
    public func getSecurityStatus() -> [SecurityFeature: Bool] {
        return PrivacyManager.shared.validateSecurityFeatures()
    }

    // MARK: - Private Methods

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
