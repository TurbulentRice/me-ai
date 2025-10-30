import Foundation

// MARK: - TextChunker Protocol

/// Protocol for chunking text into smaller segments
public protocol TextChunker: Sendable {
    /// Chunk text into segments with optional overlap
    /// - Parameters:
    ///   - text: Input text to chunk
    ///   - maxTokens: Maximum tokens per chunk
    ///   - overlap: Number of tokens to overlap between chunks
    /// - Returns: Array of text chunks
    func chunk(text: String, maxTokens: Int, overlap: Int) -> [String]
}

// MARK: - Semantic Chunker Implementation

/// Chunks text at semantic boundaries (sentences/paragraphs) with token limits
public final class SemanticChunker: TextChunker {
    private let tokenEstimator: TokenEstimator

    public init(tokenEstimator: TokenEstimator = CharacterBasedEstimator()) {
        self.tokenEstimator = tokenEstimator
    }

    public func chunk(text: String, maxTokens: Int = 512, overlap: Int = 50) -> [String] {
        // Split into sentences first
        let sentences = splitIntoSentences(text)

        var chunks: [String] = []
        var currentChunk = ""
        var currentTokens = 0
        var overlapBuffer: [String] = []

        for sentence in sentences {
            let sentenceTokens = tokenEstimator.estimateTokens(sentence)

            // If single sentence exceeds max, split it further
            if sentenceTokens > maxTokens {
                // Flush current chunk if not empty
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    overlapBuffer = getOverlapSentences(currentChunk, targetTokens: overlap)
                    currentChunk = ""
                    currentTokens = 0
                }

                // Split long sentence by words
                let wordChunks = chunkByWords(sentence, maxTokens: maxTokens, overlap: overlap)
                chunks.append(contentsOf: wordChunks)
                continue
            }

            // Check if adding this sentence would exceed limit
            if currentTokens + sentenceTokens > maxTokens && !currentChunk.isEmpty {
                // Save current chunk
                chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))

                // Start new chunk with overlap
                overlapBuffer = getOverlapSentences(currentChunk, targetTokens: overlap)
                currentChunk = overlapBuffer.joined(separator: " ") + " "
                currentTokens = tokenEstimator.estimateTokens(currentChunk)
            }

            // Add sentence to current chunk
            currentChunk += sentence + " "
            currentTokens += sentenceTokens
        }

        // Add final chunk if not empty
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return chunks.filter { !$0.isEmpty }
    }

    // MARK: - Private Helpers

    private func splitIntoSentences(_ text: String) -> [String] {
        // Use simple sentence splitting (can be improved with NaturalLanguage framework)
        var sentences: [String] = []
        var currentSentence = ""

        let sentenceEnders: Set<Character> = [".", "!", "?"]
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let lineStr = String(line).trimmingCharacters(in: .whitespaces)

            if lineStr.isEmpty {
                // Paragraph break
                if !currentSentence.isEmpty {
                    sentences.append(currentSentence)
                    currentSentence = ""
                }
                continue
            }

            for char in lineStr {
                currentSentence.append(char)

                if sentenceEnders.contains(char) {
                    // Check if next char is whitespace or end
                    let trimmed = currentSentence.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        sentences.append(trimmed)
                    }
                    currentSentence = ""
                }
            }

            // Add remaining text as sentence if at line end
            if !currentSentence.isEmpty && !currentSentence.hasSuffix(" ") {
                currentSentence += " "
            }
        }

        // Add final sentence
        if !currentSentence.isEmpty {
            sentences.append(currentSentence.trimmingCharacters(in: .whitespaces))
        }

        return sentences.filter { !$0.isEmpty }
    }

    private func getOverlapSentences(_ text: String, targetTokens: Int) -> [String] {
        let sentences = splitIntoSentences(text)
        var overlap: [String] = []
        var tokens = 0

        // Take sentences from the end until we reach target tokens
        for sentence in sentences.reversed() {
            let sentenceTokens = tokenEstimator.estimateTokens(sentence)
            if tokens + sentenceTokens > targetTokens && !overlap.isEmpty {
                break
            }
            overlap.insert(sentence, at: 0)
            tokens += sentenceTokens
        }

        return overlap
    }

    private func chunkByWords(_ text: String, maxTokens: Int, overlap: Int) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentTokens = 0

        for word in words {
            let wordTokens = tokenEstimator.estimateTokens(word)

            if currentTokens + wordTokens > maxTokens && !currentChunk.isEmpty {
                chunks.append(currentChunk.joined(separator: " "))

                // Keep overlap words
                let overlapWords = min(overlap / 4, currentChunk.count) // ~4 chars per token
                currentChunk = Array(currentChunk.suffix(overlapWords))
                currentTokens = tokenEstimator.estimateTokens(currentChunk.joined(separator: " "))
            }

            currentChunk.append(word)
            currentTokens += wordTokens
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        return chunks
    }
}

// MARK: - Token Estimation

/// Protocol for estimating token counts from text
public protocol TokenEstimator: Sendable {
    /// Estimate the number of tokens in the given text
    func estimateTokens(_ text: String) -> Int
}

/// Simple character-based token estimator (~4 characters per token)
public struct CharacterBasedEstimator: TokenEstimator {
    private let charsPerToken: Int

    public init(charsPerToken: Int = 4) {
        self.charsPerToken = charsPerToken
    }

    public func estimateTokens(_ text: String) -> Int {
        return max(1, text.count / charsPerToken)
    }
}

// MARK: - Fixed-Size Chunker (Alternative Implementation)

/// Simple chunker that splits text into fixed-size chunks with overlap
public final class FixedSizeChunker: TextChunker {
    private let tokenEstimator: TokenEstimator

    public init(tokenEstimator: TokenEstimator = CharacterBasedEstimator()) {
        self.tokenEstimator = tokenEstimator
    }

    public func chunk(text: String, maxTokens: Int = 512, overlap: Int = 50) -> [String] {
        let charsPerChunk = maxTokens * 4 // Approximate
        let overlapChars = overlap * 4

        var chunks: [String] = []
        var startIndex = text.startIndex

        while startIndex < text.endIndex {
            let endIndex = text.index(
                startIndex,
                offsetBy: charsPerChunk,
                limitedBy: text.endIndex
            ) ?? text.endIndex

            let chunk = String(text[startIndex..<endIndex])
            chunks.append(chunk)

            // Move start index with overlap
            let nextStartOffset = max(0, charsPerChunk - overlapChars)
            startIndex = text.index(
                startIndex,
                offsetBy: nextStartOffset,
                limitedBy: text.endIndex
            ) ?? text.endIndex
        }

        return chunks.filter { !$0.isEmpty }
    }
}
