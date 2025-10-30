import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(Vision)
import Vision
#endif

// MARK: - Document Ingestion Pipeline

/// Pipeline for ingesting documents into the knowledge base
public final class DocumentIngestion: Sendable {
    private let chunker: TextChunker
    private let embedder: Embedder
    private let database: VectorDatabase

    public init(
        chunker: TextChunker,
        embedder: Embedder,
        database: VectorDatabase
    ) {
        self.chunker = chunker
        self.embedder = embedder
        self.database = database
    }

    // MARK: - Public API

    /// Ingest a document from a file URL
    /// - Parameters:
    ///   - fileURL: URL to the document file
    ///   - maxChunkTokens: Maximum tokens per chunk
    ///   - chunkOverlap: Overlap tokens between chunks
    /// - Returns: Ingested document with metadata
    public func ingest(
        fileURL: URL,
        maxChunkTokens: Int = 512,
        chunkOverlap: Int = 50
    ) async throws -> Document {
        // 1. Extract text from file
        let text = try await extractText(from: fileURL)

        // 2. Create document record
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let document = Document(
            id: 0, // Will be auto-generated
            filename: fileURL.lastPathComponent,
            mimeType: getMimeType(for: fileURL),
            fileSize: Int64(fileSize),
            sourceURL: fileURL,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 0
        )

        let docId = try database.insertDocument(document)

        // 3. Chunk text
        let chunkTexts = chunker.chunk(
            text: text,
            maxTokens: maxChunkTokens,
            overlap: chunkOverlap
        )

        // 4. Generate embeddings for all chunks
        let embeddings = try await embedder.embed(texts: chunkTexts)

        // 5. Create chunk objects
        let chunks = try chunkTexts.enumerated().map { index, chunkText in
            guard index < embeddings.count else {
                throw IngestionError.embeddingMismatch
            }

            return Chunk(
                id: 0, // Will be auto-generated
                docId: docId,
                text: chunkText,
                embedding: embeddings[index],
                position: index,
                meta: ChunkMetadata(
                    startOffset: 0, // TODO: Calculate actual offsets
                    endOffset: chunkText.count,
                    tokenCount: chunkText.count / 4, // Rough estimate
                    pageNumber: nil
                ),
                createdAt: Date()
            )
        }

        // 6. Insert chunks into database
        try database.insertChunks(chunks)

        // 7. Return updated document
        return try database.getDocument(id: docId) ?? document
    }

    /// Ingest text directly (without file)
    /// - Parameters:
    ///   - text: Text content to ingest
    ///   - filename: Virtual filename for the document
    ///   - maxChunkTokens: Maximum tokens per chunk
    ///   - chunkOverlap: Overlap tokens between chunks
    /// - Returns: Ingested document
    public func ingestText(
        _ text: String,
        filename: String = "untitled.txt",
        maxChunkTokens: Int = 512,
        chunkOverlap: Int = 50
    ) async throws -> Document {
        // Create document record
        let document = Document(
            id: 0,
            filename: filename,
            mimeType: "text/plain",
            fileSize: Int64(text.utf8.count),
            sourceURL: nil,
            createdAt: Date(),
            lastModified: Date(),
            chunkCount: 0
        )

        let docId = try database.insertDocument(document)

        // Chunk text
        let chunkTexts = chunker.chunk(
            text: text,
            maxTokens: maxChunkTokens,
            overlap: chunkOverlap
        )

        // Generate embeddings
        let embeddings = try await embedder.embed(texts: chunkTexts)

        // Create and insert chunks
        let chunks = try chunkTexts.enumerated().map { index, chunkText in
            guard index < embeddings.count else {
                throw IngestionError.embeddingMismatch
            }

            return Chunk(
                id: 0,
                docId: docId,
                text: chunkText,
                embedding: embeddings[index],
                position: index,
                meta: ChunkMetadata(
                    startOffset: 0,
                    endOffset: chunkText.count,
                    tokenCount: chunkText.count / 4,
                    pageNumber: nil
                ),
                createdAt: Date()
            )
        }

        try database.insertChunks(chunks)

        return try database.getDocument(id: docId) ?? document
    }

    // MARK: - Text Extraction

    private func extractText(from url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt", "md", "markdown":
            return try extractPlainText(from: url)
        case "pdf":
            return try await extractPDFText(from: url)
        default:
            throw IngestionError.unsupportedFileType(ext)
        }
    }

    private func extractPlainText(from url: URL) throws -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw IngestionError.textExtractionFailed("Unable to read file as UTF-8")
        }
        return text
    }

    private func extractPDFText(from url: URL) async throws -> String {
        #if canImport(PDFKit)
        guard let pdf = PDFDocument(url: url) else {
            throw IngestionError.textExtractionFailed("Unable to open PDF")
        }

        var fullText = ""
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            if let pageText = page.string {
                fullText += pageText
                fullText += "\n\n" // Separate pages
            }
        }

        guard !fullText.isEmpty else {
            throw IngestionError.textExtractionFailed("PDF contains no extractable text")
        }

        return fullText
        #else
        throw IngestionError.unsupportedFileType("PDF support not available on this platform")
        #endif
    }

    // MARK: - Helpers

    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt":
            return "text/plain"
        case "md", "markdown":
            return "text/markdown"
        case "pdf":
            return "application/pdf"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - Ingestion Errors

/// Errors that can occur during document ingestion
public enum IngestionError: Error, LocalizedError {
    case unsupportedFileType(String)
    case textExtractionFailed(String)
    case embeddingMismatch
    case invalidDocument

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext)"
        case .textExtractionFailed(let message):
            return "Text extraction failed: \(message)"
        case .embeddingMismatch:
            return "Number of embeddings doesn't match number of chunks"
        case .invalidDocument:
            return "Document is invalid or corrupted"
        }
    }
}
