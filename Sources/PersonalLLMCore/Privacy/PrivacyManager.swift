import Foundation

/// Manages privacy and security settings for the application
public final class PrivacyManager {
    public static let shared = PrivacyManager()

    private let keychainManager = KeychainManager.shared

    private init() {}

    // MARK: - Privacy Settings

    /// Check if offline mode is enabled
    public var isOfflineModeEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "privacy.offlineMode")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "privacy.offlineMode")
        }
    }

    /// Check if encryption is enabled
    public var isEncryptionEnabled: Bool {
        do {
            _ = try keychainManager.getOrCreateDatabaseKey()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Data Management

    /// Get database file size in bytes
    public func getDatabaseSize(at path: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }
        return fileSize
    }

    /// Format file size for display
    public func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Delete all application data
    /// - Warning: This operation cannot be undone
    public func deleteAllData(database: VectorDatabase) throws {
        // If using encrypted database, use secure delete
        if let encryptedDB = database as? EncryptedVectorDatabase {
            try encryptedDB.secureDeleteAll()
        } else {
            // Delete all documents from database
            let documents = try database.getAllDocuments()
            for document in documents {
                try database.deleteDocument(id: document.id)
            }
        }
    }

    /// Delete database file from disk
    public func deleteDatabaseFile(at path: URL) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return // Already deleted
        }

        try FileManager.default.removeItem(at: path)
    }

    /// Reset encryption (generates new key)
    /// - Warning: This will make existing encrypted data unreadable
    public func resetEncryption() throws {
        try keychainManager.deleteDatabaseKey()
        _ = try keychainManager.getOrCreateDatabaseKey()
    }

    // MARK: - Security Validation

    /// Validate that required security features are available
    public func validateSecurityFeatures() -> [SecurityFeature: Bool] {
        var features: [SecurityFeature: Bool] = [:]

        // Check keychain availability
        features[.keychainAccess] = isEncryptionEnabled

        // Check file protection
        features[.fileProtection] = FileManager.default.ubiquityIdentityToken != nil

        // Check biometric availability (if needed in future)
        features[.biometricAuth] = false // TODO: Implement biometric check

        return features
    }

    /// Generate privacy report
    public func generatePrivacyReport(database: VectorDatabase, dbPath: URL) throws -> PrivacyReport {
        let documentCount = try database.getDocumentCount()
        let chunkCount = try database.getChunkCount()
        let databaseSize = getDatabaseSize(at: dbPath)

        return PrivacyReport(
            encryptionEnabled: isEncryptionEnabled,
            offlineModeEnabled: isOfflineModeEnabled,
            documentCount: documentCount,
            chunkCount: chunkCount,
            databaseSizeBytes: databaseSize,
            lastUpdated: Date()
        )
    }
}

// MARK: - Supporting Types

public enum SecurityFeature: String {
    case keychainAccess = "Keychain Access"
    case fileProtection = "File Protection"
    case biometricAuth = "Biometric Authentication"
}

public struct PrivacyReport: Codable {
    public let encryptionEnabled: Bool
    public let offlineModeEnabled: Bool
    public let documentCount: Int
    public let chunkCount: Int
    public let databaseSizeBytes: Int64
    public let lastUpdated: Date

    public var databaseSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: databaseSizeBytes, countStyle: .file)
    }
}
