import Foundation
import Combine
import PersonalLLMCore

/// View model for chat interface
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private let ragEngine: RAGEngine

    init(ragEngine: RAGEngine) {
        self.ragEngine = ragEngine
    }

    /// Send a message and get streaming response
    func sendMessage(_ query: String) async {
        guard !query.isEmpty else { return }

        // Add user message
        let userMessage = Message(role: .user, content: query, citations: [])
        messages.append(userMessage)

        isGenerating = true
        errorMessage = nil

        defer { isGenerating = false }

        do {
            // Create assistant message placeholder
            let assistantMessage = Message(role: .assistant, content: "", citations: [])
            messages.append(assistantMessage)
            let messageIndex = messages.count - 1

            // Get RAG response
            let (stream, citations) = try await ragEngine.answer(query: query, topK: 3)

            // Stream tokens
            for await token in stream {
                messages[messageIndex].content += token
            }

            // Add citations
            messages[messageIndex].citations = citations

        } catch {
            errorMessage = error.localizedDescription

            // Add error message
            let errorMsg = Message(
                role: .assistant,
                content: "Sorry, I encountered an error: \(error.localizedDescription)",
                citations: []
            )

            if messages.last?.role == .assistant && messages.last?.content.isEmpty == true {
                messages[messages.count - 1] = errorMsg
            } else {
                messages.append(errorMsg)
            }
        }
    }

    /// Clear all messages
    func clearChat() {
        messages.removeAll()
    }

    /// Delete a specific message
    func deleteMessage(at index: Int) {
        guard index < messages.count else { return }
        messages.remove(at: index)
    }
}

/// Represents a chat message
struct Message: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var citations: [Citation]
    let timestamp: Date

    init(role: Role, content: String, citations: [Citation]) {
        self.role = role
        self.content = content
        self.citations = citations
        self.timestamp = Date()
    }

    enum Role {
        case user
        case assistant
    }
}
