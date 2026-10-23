import SwiftUI
import TwinCore

/// Twin Assistant chat: organize suggestions for the current folder plus
/// a conversation about how to do file tasks in Twin. Answers come from
/// Apple's on-device model when available, otherwise TwinHelp's rules.
struct AssistantView: View {
    @ObservedObject var viewModel: PaneViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chat = AssistantChat()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            proactiveSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            organizeSection
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            Divider()
            transcript
            suggestions
            inputBar
            statusBar
        }
        .frame(width: 500, height: 640)
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles").foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 1) {
                Text("Twin Assistant").font(.headline)
                Text(viewModel.currentURL.path)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button("Clear") { chat.clear() }
                .font(.caption)
            Button("Close") { dismiss() }
        }
        .padding(14)
    }

    /// Proactive findings for this folder — shown without being asked.
    @ViewBuilder
    private var proactiveSection: some View {
        if let insights = viewModel.insights, insights.hasFindings {
            VStack(alignment: .leading, spacing: 6) {
                Text("Twin noticed").font(.subheadline.bold())
                if !insights.permissionRisks.isEmpty {
                    Label(
                        riskText(insights),
                        systemImage: "exclamationmark.shield"
                    )
                    .font(.caption).foregroundStyle(.orange)
                }
                if !insights.orphanFiles.isEmpty {
                    HStack(spacing: 8) {
                        Label("\(insights.orphanFiles.count) orphan file(s) untouched for 90+ days.",
                              systemImage: "tray")
                            .font(.caption)
                        Button("Collect into Kartotek/") { viewModel.collectOrphans() }
                            .controlSize(.small)
                    }
                }
                if !insights.oversizedFiles.isEmpty {
                    Label(oversizedText(insights), systemImage: "externaldrive")
                        .font(.caption)
                }
                if !insights.emptyFolders.isEmpty {
                    Label("\(insights.emptyFolders.count) empty folder(s).", systemImage: "folder")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Build Kartotek (index of this folder)") {
                    _ = viewModel.buildCatalog()
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func riskText(_ insights: FolderInsightsService.Insights) -> String {
        let octal = insights.permissionRisks.first?.octal ?? ""
        return "\(insights.permissionRisks.count) file(s) anyone can write to (\(octal)) — check Permissions with Cmd+I."
    }

    private func oversizedText(_ insights: FolderInsightsService.Insights) -> String {
        let biggest = insights.oversizedFiles.first?.url.lastPathComponent ?? ""
        return "\(insights.oversizedFiles.count) file(s) over 100 MB — biggest: \(biggest)."
    }

    private var organizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Organize this folder").font(.subheadline.bold())
            let plan = viewModel.organizePlanSummary
            if plan.isEmpty {
                Text("No loose files here to sort. Folders stay where they are.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    ForEach(plan, id: \.category) { row in
                        Label("\(row.count) → \(row.category)", systemImage: "folder")
                            .font(.caption)
                    }
                }
                HStack(spacing: 8) {
                    Button("Sort Into Folders") { viewModel.organizeFolder() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Text("Moved, not copied. Nothing is deleted.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(chat.messages) { message in
                        HStack {
                            if message.isUser { Spacer(minLength: 60) }
                            Text(message.text)
                                .textSelection(.enabled)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(message.isUser ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                                .foregroundStyle(message.isUser ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            if !message.isUser { Spacer(minLength: 60) }
                        }
                        .id(message.id)
                    }
                    if chat.isThinking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Thinking locally…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
            }
            .onChange(of: chat.messages.count) { _, _ in
                if let last = chat.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TwinHelp.suggestions, id: \.self) { suggestion in
                    Button(suggestion) { send(suggestion) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(chat.isThinking)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask how to do something in Twin…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { send(draft) }
            Button("Ask") { send(draft) }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || chat.isThinking)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var statusBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.shield")
            Text(chat.modelStatusText)
            Spacer()
            Text("Try: “How do I encrypt a file?”")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        draft = ""
        // Task execution: kartotek/catalog commands run immediately.
        let lowered = question.lowercased()
        if lowered.contains("kartotek") || lowered.contains("catalog") || lowered.contains("index") {
            if let path = viewModel.buildCatalog() {
                chat.appendExchange(user: question, assistant: "Done — I created the catalog at \(path). It lists every file with" +
                    "size, modified date and MD5.")
                return
            }
        }
        chat.send(question, folder: viewModel.currentURL, folderSummary: FolderSummary.summary(for: viewModel))
    }
}
