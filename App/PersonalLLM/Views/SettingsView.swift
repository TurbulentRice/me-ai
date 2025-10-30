import SwiftUI
import PersonalLLMCore

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var showingDeleteConfirmation = false
    @State private var modelInfo = "Loading..."

    var body: some View {
        List {
            // Privacy Section
            Section {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("All Data Local")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Toggle("Offline Mode", isOn: $viewModel.offlineMode)
                    .disabled(true) // Always offline in P0

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Personal AI keeps all data on your device. Nothing is sent to external servers.")
            }

            // Storage Section
            Section("Storage") {
                HStack {
                    Text("Documents")
                    Spacer()
                    Text("\(viewModel.documentCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Database Size")
                    Spacer()
                    Text(viewModel.databaseSize)
                        .foregroundStyle(.secondary)
                }
            }

            // Model Section
            Section("Model") {
                HStack {
                    Text("Active Model")
                    Spacer()
                    Text("Phi-3 Mini (Mock)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.modelLoaded ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.modelLoaded ? "Loaded" : "Initializing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Details")
                    Spacer()
                    Text(modelInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .task {
                    modelInfo = await viewModel.getModelInfo()
                }
            }

            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(viewModel.getAppVersion())
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://github.com")!) {
                    HStack {
                        Text("GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }

                HStack {
                    Text("Built with")
                    Spacer()
                    Text("Swift, SwiftUI, SQLite")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            viewModel.loadStats()
        }
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAllData()
            }
        } message: {
            Text("This will permanently delete all documents, embeddings, and chat history. This action cannot be undone.")
        }
    }
}

#Preview {
    NavigationView {
        SettingsView(viewModel: SettingsViewModel(
            manager: DocumentManager(
                database: try! SQLiteVectorDB(dbPath: FileManager.default.temporaryDirectory.appendingPathComponent("preview.db")),
                ingestion: DocumentIngestion(
                    chunker: SemanticChunker(),
                    embedder: MockEmbedder(dimension: 384),
                    database: try! SQLiteVectorDB(dbPath: FileManager.default.temporaryDirectory.appendingPathComponent("preview.db"))
                )
            ),
            llm: MockLLM()
        ))
    }
}
