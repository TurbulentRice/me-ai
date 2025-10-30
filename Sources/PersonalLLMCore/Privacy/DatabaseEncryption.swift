import Foundation
import CryptoKit

/// Provides encryption/decryption for sensitive database fields using AES-GCM
public final class DatabaseEncryption: Sendable {
    private let symmetricKey: SymmetricKey

    /// Initialize with encryption key from Keychain
    public init() throws {
        let keyString = try KeychainManager.shared.getOrCreateDatabaseKey()
        guard let keyData = Data(base64Encoded: keyString) else {
            throw EncryptionError.invalidKey
        }

        // Use SHA256 to derive a proper 256-bit key
        let hash = SHA256.hash(data: keyData)
        self.symmetricKey = SymmetricKey(data: hash)
    }

    /// Encrypt text data
    /// - Parameter plaintext: The text to encrypt
    /// - Returns: Base64-encoded encrypted data with nonce
    /// - Throws: EncryptionError if encryption fails
    public func encrypt(_ plaintext: String) throws -> String {
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.invalidInput
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)

            // Combine nonce + ciphertext + tag for storage
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }

            return combined.base64EncodedString()
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// Decrypt encrypted text data
    /// - Parameter ciphertext: Base64-encoded encrypted data
    /// - Returns: Decrypted plaintext string
    /// - Throws: EncryptionError if decryption fails
    public func decrypt(_ ciphertext: String) throws -> String {
        guard let combined = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidInput
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)

            guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
                throw EncryptionError.decryptionFailed
            }

            return plaintext
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// Encrypt binary data (e.g., embeddings)
    /// - Parameter data: The data to encrypt
    /// - Returns: Encrypted data
    /// - Throws: EncryptionError if encryption fails
    public func encryptData(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// Decrypt binary data
    /// - Parameter encryptedData: The encrypted data
    /// - Returns: Decrypted data
    /// - Throws: EncryptionError if decryption fails
    public func decryptData(_ encryptedData: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
}

// MARK: - Error Types

public enum EncryptionError: LocalizedError {
    case invalidKey
    case invalidInput
    case encryptionFailed
    case decryptionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid encryption key format"
        case .invalidInput:
            return "Invalid input data for encryption/decryption"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data - data may be corrupted or key is incorrect"
        }
    }
}
