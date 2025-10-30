import SwiftUI
import PersonalLLMCore

struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }

                        // Scroll anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.red.opacity(0.1))
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("Ask a question...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .disabled(viewModel.isGenerating)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: viewModel.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty && !viewModel.isGenerating)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.clearChat()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.messages.isEmpty)
            }
        }
    }

    private func sendMessage() {
        let query = inputText
        inputText = ""
        isInputFocused = false

        Task {
            await viewModel.sendMessage(query)
        }
    }
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Message content
                Text(message.content.isEmpty ? "Thinking..." : message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.15))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                    .textSelection(.enabled)

                // Citations
                if !message.citations.isEmpty {
                    CitationsView(citations: message.citations)
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}

#Preview {
    NavigationView {
        ChatView(viewModel: ChatViewModel(
            ragEngine: RAGEngine(
                embedder: MockEmbedder(dimension: 384),
                database: try! SQLiteVectorDB(dbPath: FileManager.default.temporaryDirectory.appendingPathComponent("preview.db")),
                llm: MockLLM(),
                config: .default
            )
        ))
    }
}
