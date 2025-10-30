import Foundation
import Security

/// Manages secure storage of encryption keys in the iOS Keychain
public final class KeychainManager {
    public static let shared = KeychainManager()

    private init() {}

    // MARK: - Public Interface

    /// Retrieves or creates a database encryption key
    /// - Returns: Base64-encoded encryption key
    /// - Throws: KeychainError if key operations fail
    public func getOrCreateDatabaseKey() throws -> String {
        let service = "com.personalllm.database"
        let account = "encryption-key"

        // Try to retrieve existing key
        if let existingKey = try? retrieveKey(service: service, account: account) {
            return existingKey
        }

        // Generate new key if none exists
        let newKey = generateRandomKey()
        try storeKey(newKey, service: service, account: account)
        return newKey
    }

    /// Deletes the database encryption key from keychain
    /// - Warning: This will make existing encrypted data unrecoverable
    public func deleteDatabaseKey() throws {
        let service = "com.personalllm.database"
        let account = "encryption-key"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }

    // MARK: - Private Helpers

    private func generateRandomKey(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

        guard status == errSecSuccess else {
            // Fallback to less secure random generation if SecRandom fails
            bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        }

        return Data(bytes).base64EncodedString()
    }

    private func storeKey(_ key: String, service: String, account: String) throws {
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainError.invalidKeyData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Key already exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: keyData
            ]

            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unableToStore(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unableToStore(status)
        }
    }

    private func retrieveKey(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.unableToRetrieve(status)
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidKeyData
        }

        return key
    }
}

// MARK: - Error Types

public enum KeychainError: LocalizedError {
    case unableToStore(OSStatus)
    case unableToRetrieve(OSStatus)
    case unableToDelete(OSStatus)
    case invalidKeyData

    public var errorDescription: String? {
        switch self {
        case .unableToStore(let status):
            return "Failed to store key in keychain: \(statusMessage(status))"
        case .unableToRetrieve(let status):
            return "Failed to retrieve key from keychain: \(statusMessage(status))"
        case .unableToDelete(let status):
            return "Failed to delete key from keychain: \(statusMessage(status))"
        case .invalidKeyData:
            return "Invalid key data format"
        }
    }

    private func statusMessage(_ status: OSStatus) -> String {
        if let errorMessage = SecCopyErrorMessageString(status, nil) {
            return String(errorMessage)
        }
        return "Error code: \(status)"
    }
}
