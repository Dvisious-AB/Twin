import SwiftUI

/// Twin Assistant: organize suggestions for the current folder plus
/// questions answered locally. Uses Apple's on-device Foundation Models
/// when available (macOS 26+), otherwise a small rule-based helper.
/// Nothing leaves the machine either way.
struct AssistantView: View {
    @ObservedObject var viewModel: PaneViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var answer: String?
    @State private var thinking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text("Twin Assistant").font(.title3.bold())
                Spacer()
                Text(viewModel.currentURL.lastPathComponent)
                    .font(.caption).foregroundStyle(.secondary)
            }

            organizeSection

            Divider()

            Text("Ask Twin").font(.headline)
            HStack {
                TextField("How do I…?", text: $question)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { ask() }
                Button("Ask") { ask() }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
            }
            if thinking {
                ProgressView("Thinking locally…")
            } else if let answer {
                Text(answer)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Text(AssistantEngine.statusText)
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var organizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Organize this folder").font(.headline)
            let plan = viewModel.organizePlanSummary
            if plan.isEmpty {
                Text("No loose files here to sort. Folders stay where they are.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(plan, id: \.category) { row in
                    Label("\(row.count) file(s) → \(row.category)/", systemImage: "folder")
                        .font(.callout)
                }
                Button("Sort Into Folders") { viewModel.organizeFolder() }
                    .buttonStyle(.borderedProminent)
                Text("Files are moved, not copied. Nothing is deleted.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func ask() {
        let prompt = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        thinking = true
        answer = nil
        Task {
            let reply = await AssistantEngine.answer(to: prompt, folder: viewModel.currentURL)
            await MainActor.run {
                answer = reply
                thinking = false
            }
        }
    }
}
