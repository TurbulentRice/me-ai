import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("Personal LLM")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Privacy-first AI assistant")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Phase 0: Infrastructure Complete ✓")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .padding()
            .navigationTitle("Personal LLM")
        }
    }
}

#Preview {
    ContentView()
}
