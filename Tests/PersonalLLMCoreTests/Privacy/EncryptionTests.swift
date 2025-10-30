import XCTest
@testable import PersonalLLMCore

final class EncryptionTests: XCTestCase {

    // MARK: - Keychain Tests

    func testKeychainKeyGeneration() throws {
        // Clean up any existing key
        try? KeychainManager.shared.deleteDatabaseKey()

        // Generate new key
        let key1 = try KeychainManager.shared.getOrCreateDatabaseKey()
        XCTAssertFalse(key1.isEmpty, "Generated key should not be empty")

        // Verify same key is returned on subsequent calls
        let key2 = try KeychainManager.shared.getOrCreateDatabaseKey()
        XCTAssertEqual(key1, key2, "Should return same key on subsequent calls")

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    func testKeychainKeyDeletion() throws {
        // Create a key
        _ = try KeychainManager.shared.getOrCreateDatabaseKey()

        // Delete it
        try KeychainManager.shared.deleteDatabaseKey()

        // Verify new key is generated (different from deleted one)
        let newKey = try KeychainManager.shared.getOrCreateDatabaseKey()
        XCTAssertFalse(newKey.isEmpty)

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    // MARK: - Encryption Tests

    func testBasicEncryptionDecryption() throws {
        let encryption = try DatabaseEncryption()

        let plaintext = "Hello, World! This is a test message."
        let encrypted = try encryption.encrypt(plaintext)

        XCTAssertNotEqual(plaintext, encrypted, "Encrypted text should differ from plaintext")

        let decrypted = try encryption.decrypt(encrypted)
        XCTAssertEqual(plaintext, decrypted, "Decrypted text should match original")

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    func testEncryptionWithUnicode() throws {
        let encryption = try DatabaseEncryption()

        let plaintext = "Hello 世界! 🔒 Encryption test with émojis and spëcial çhars"
        let encrypted = try encryption.encrypt(plaintext)
        let decrypted = try encryption.decrypt(encrypted)

        XCTAssertEqual(plaintext, decrypted, "Should handle Unicode correctly")

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    func testEncryptionWithLargeText() throws {
        let encryption = try DatabaseEncryption()

        // Generate large text (1MB)
        let plaintext = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 20000)

        let encrypted = try encryption.encrypt(plaintext)
        let decrypted = try encryption.decrypt(encrypted)

        XCTAssertEqual(plaintext, decrypted, "Should handle large text correctly")

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    func testDataEncryptionDecryption() throws {
        let encryption = try DatabaseEncryption()

        let originalData = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        let encrypted = try encryption.encryptData(originalData)

        XCTAssertNotEqual(originalData, encrypted, "Encrypted data should differ from original")

        let decrypted = try encryption.decryptData(encrypted)
        XCTAssertEqual(originalData, decrypted, "Decrypted data should match original")

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    func testInvalidDecryption() throws {
        let encryption = try DatabaseEncryption()

        // Try to decrypt invalid data
        let invalidEncrypted = "this is not valid encrypted data"

        XCTAssertThrowsError(try encryption.decrypt(invalidEncrypted)) { error in
            XCTAssertTrue(error is EncryptionError, "Should throw EncryptionError")
        }

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    func testEncryptionKeyChange() throws {
        let encryption1 = try DatabaseEncryption()
        let plaintext = "Test message"
        let encrypted = try encryption1.encrypt(plaintext)

        // Delete and regenerate key
        try KeychainManager.shared.deleteDatabaseKey()

        let encryption2 = try DatabaseEncryption()

        // Should not be able to decrypt with new key
        XCTAssertThrowsError(try encryption2.decrypt(encrypted)) { error in
            XCTAssertTrue(error is EncryptionError, "Should fail with different key")
        }

        // Clean up
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    // MARK: - Encrypted Database Tests

    func testEncryptedDatabaseChunkStorage() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")

        let encryptedDB = try EncryptedVectorDatabase(dbPath: tempURL)

        // Create test document
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 100,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 1
        )

        let docId = try encryptedDB.insertDocument(document)

        // Create test chunk with sensitive text
        let sensitiveText = "This is sensitive information that should be encrypted"
        let chunk = Chunk(
            id: 0,
            docId: docId,
            text: sensitiveText,
            embedding: [0.1, 0.2, 0.3],
            position: 0,
            meta: ChunkMetadata(startOffset: 0, endOffset: 100, tokenCount: 10, pageNumber: nil),
            createdAt: Date()
        )

        try encryptedDB.insertChunks([chunk])

        // Retrieve and verify decryption
        let retrievedChunks = try encryptedDB.getChunks(forDocumentId: docId)
        XCTAssertEqual(retrievedChunks.count, 1)
        XCTAssertEqual(retrievedChunks[0].text, sensitiveText, "Chunk text should be decrypted correctly")

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    func testEncryptedDatabaseSearch() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")

        let encryptedDB = try EncryptedVectorDatabase(dbPath: tempURL)

        // Create document and chunks
        let document = Document(
            id: 0,
            filename: "test.txt",
            mimeType: "text/plain",
            fileSize: 100,
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 2
        )

        let docId = try encryptedDB.insertDocument(document)

        let chunks = [
            Chunk(
                id: 0,
                docId: docId,
                text: "First sensitive chunk",
                embedding: [1.0, 0.0, 0.0],
                position: 0,
                meta: ChunkMetadata(startOffset: 0, endOffset: 20, tokenCount: 3, pageNumber: nil),
                createdAt: Date()
            ),
            Chunk(
                id: 0,
                docId: docId,
                text: "Second sensitive chunk",
                embedding: [0.9, 0.1, 0.0],
                position: 1,
                meta: ChunkMetadata(startOffset: 21, endOffset: 43, tokenCount: 3, pageNumber: nil),
                createdAt: Date()
            )
        ]

        try encryptedDB.insertChunks(chunks)

        // Search for similar chunks
        let queryEmbedding: [Float] = [0.95, 0.05, 0.0]
        let results = try encryptedDB.searchSimilar(queryEmbedding: queryEmbedding, topK: 2)

        XCTAssertEqual(results.count, 2, "Should return 2 results")
        XCTAssertTrue(results[0].chunk.text.contains("sensitive"), "Chunk text should be decrypted")

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
        try? KeychainManager.shared.deleteDatabaseKey()
    }

    // MARK: - Cleanup

    override func tearDown() {
        // Ensure keychain is cleaned up after each test
        try? KeychainManager.shared.deleteDatabaseKey()
        super.tearDown()
    }
}
