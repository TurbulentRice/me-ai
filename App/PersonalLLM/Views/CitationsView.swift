import SwiftUI
import PersonalLLMCore

struct CitationsView: View {
    let citations: [Citation]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(citations.count) source\(citations.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(citations.enumerated()), id: \.element.id) { index, citation in
                        CitationRow(citation: citation, index: index + 1)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
    }
}

struct CitationRow: View {
    let citation: Citation
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Source number
            Text("\(index)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 2) {
                // Document name
                Text(citation.documentName)
                    .font(.caption)
                    .fontWeight(.medium)

                // Chunk preview
                Text(String(citation.chunkText.prefix(100)) + (citation.chunkText.count > 100 ? "..." : ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Relevance score
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                    Text("Relevance: \(String(format: "%.1f%%", citation.relevanceScore * 100))")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }
}

#Preview("Single Citation") {
    CitationsView(citations: [
        Citation(
            id: UUID(),
            documentName: "research.pdf",
            documentId: 1,
            chunkText: "This is a sample chunk of text from a document that provides context for the answer.",
            chunkPosition: 0,
            relevanceScore: 0.85,
            sourceIndex: 1
        )
    ])
    .padding()
}

#Preview("Multiple Citations") {
    CitationsView(citations: [
        Citation(
            id: UUID(),
            documentName: "research.pdf",
            documentId: 1,
            chunkText: "This is a sample chunk of text from a document that provides context for the answer.",
            chunkPosition: 0,
            relevanceScore: 0.85,
            sourceIndex: 1
        ),
        Citation(
            id: UUID(),
            documentName: "notes.txt",
            documentId: 2,
            chunkText: "Another relevant piece of information from a different source.",
            chunkPosition: 0,
            relevanceScore: 0.72,
            sourceIndex: 2
        ),
        Citation(
            id: UUID(),
            documentName: "guide.md",
            documentId: 3,
            chunkText: "Additional context that helps answer the user's question with more detail.",
            chunkPosition: 1,
            relevanceScore: 0.68,
            sourceIndex: 3
        )
    ])
    .padding()
}
