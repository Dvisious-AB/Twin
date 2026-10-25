import SwiftUI
import TwinCore

/// Gemma docked at the bottom of the main window — the
/// assistant-first entry point (2026: writing what you want is
/// the default, the TC function bar stays right above it).
/// Nothing destructive runs from here without the existing
/// confirmation flows, and multi-file actions first show a plan
/// with an explicit Run button (behavioral-team requirement).
struct GemmaBar: View {
    @ObservedObject var pane: PaneViewModel
    /// Opens the full Gemma chat (sheet or column) with this text.
    var onOpenChat: (String) -> Void = { _ in }
    /// Routes Delete wishes to the existing confirmation dialog.
    var onRequestDelete: () -> Void = {}
    /// Toggle the embedded Gemma column.
    var onToggleColumn: () -> Void = {}

    @State private var text = ""
    @State private var response: String?
    @State private var pending: Pending?
    @State private var findResults: [AssistantFind.Scored] = []
    @State private var isBusy = false
    @FocusState private var fieldFocused: Bool

    private enum Pending {
        case packFolder(count: Int)
        case packSelection(count: Int)
        case organize(plan: [(category: String, count: Int)])
    }

    private var isSwedish: Bool { TwinLanguage.isSwedish }

    var body: some View {
        VStack(spacing: 0) {
            if let response {
                responseRow(response)
            }
            if !findResults.isEmpty {
                findResultsRow
            }
            HStack(spacing: 10) {
                GemmaRobotView(state: isBusy ? .thinking : .idle, size: 32)
                TextField(
                    isSwedish
                        ? "Skriv till Gemma… t.ex. ”skapa en zip av filerna i den här katalogen”"
                        : "Write to Gemma… e.g. “create a zip of the files in this folder”",
                    text: $text
                )
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .accessibilityIdentifier("gemmaBarField")
                .onSubmit(submit)
                if let pending {
                    Button(isSwedish ? "Avbryt" : "Cancel") {
                        self.pending = nil
                        response = isSwedish ? "Okej, jag gör ingenting." : "Okay, doing nothing."
                    }
                    Button(isSwedish ? "Utför" : "Run") { runPending(pending) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("gemmaRunButton")
                } else {
                    Button(isSwedish ? "Fråga" : "Ask") { submit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
                }
                Button {
                    onToggleColumn()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .help(isSwedish ? "Visa/dölj Gemma-kolumnen" : "Show/hide the Gemma column")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) { Divider() }
        // Cmd+K jumps to Gemma from anywhere in the window.
        .background(
            Button("") { fieldFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        )
    }

    private func responseRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                response = nil
                findResults = []
            } label: {
                Image(systemName: "xmark").font(.caption2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
    }

    private var findResultsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(findResults.prefix(6)) { result in
                    Button {
                        pane.revealResult(result.match.url)
                        response = (isSwedish ? "Visar " : "Showing ")
                            + result.match.url.lastPathComponent + " i panelen."
                        findResults = []
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                            Text(result.match.url.lastPathComponent).lineLimit(1)
                            Text(result.match.url.deletingLastPathComponent().lastPathComponent)
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Intent execution

    private func submit() {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isBusy else { return }
        text = ""
        findResults = []
        DebugLog.shared.info("gemma.input", "question", context: ["text": question])
        switch AssistantIntent.parse(question) {
        case .packCurrentFolder:
            let count = pane.items.count
            guard count > 0 else {
                response = isSwedish ? "Mappen är tom — inget att packa." : "The folder is empty — nothing to pack."
                return
            }
            pending = .packFolder(count: count)
            response = (isSwedish
                ? "Jag packar alla \(count) objekt i \(pane.currentURL.lastPathComponent) till en zip här. Kör?"
                : "I'll pack all \(count) items in \(pane.currentURL.lastPathComponent) into a zip here. Run?")
        case .packSelection:
            let count = pane.selection.count
            guard count > 0 else {
                response = isSwedish ? "Markera filerna först — eller säg ”zippa hela katalogen”."
                    : "Select the files first — or say “zip the whole folder”."
                return
            }
            pending = .packSelection(count: count)
            response = (isSwedish
                ? "Jag packar \(count) markerade objekt till en zip. Kör?"
                : "I'll pack \(count) selected items into a zip. Run?")
        case .organizeFolder:
            let plan = pane.organizePlanSummary
            guard !plan.isEmpty else {
                response = isSwedish ? "Inga lösa filer att sortera här." : "No loose files to sort here."
                return
            }
            pending = .organize(plan: plan)
            let detail = plan.map { "\($0.count) \($0.category.lowercased())" }.joined(separator: ", ")
            response = (isSwedish
                ? "Jag sorterar lösa filer i mappar: \(detail). Flyttas, kopieras inte. Kör?"
                : "I'll sort loose files into folders: \(detail). Moved, not copied. Run?")
        case .createFolder(let name):
            pane.createFolder(named: name)
            response = (isSwedish
                ? "Klart — mappen \(name) är skapad. Med tangenterna: Cmd+7."
                : "Done — folder \(name) created. With keys: Cmd+7.")
            logExec("createFolder", name)
        case .deleteSelection:
            guard !pane.selection.isEmpty else {
                response = isSwedish ? "Markera först det som ska raderas." : "Select what to delete first."
                return
            }
            response = isSwedish ? "Radering kräver din bekräftelse — dialogen öppnas."
                : "Deleting needs your confirmation — opening the dialog."
            onRequestDelete()
        case .largestFile:
            response = FolderSummary.facts(for: pane).answer(to: question)
                ?? (isSwedish ? "Mappen är tom." : "The folder is empty.")
        case .find(let object):
            runFind(question: object, original: question)
        case .chat:
            onOpenChat(question)
        }
    }

    private func runPending(_ action: Pending) {
        pending = nil
        switch action {
        case .packFolder:
            let summary = pane.packCurrentFolder()
            response = summary + (isSwedish
                ? " Med tangenterna: markera allt (Cmd+A) + Cmd+Shift+C."
                : " With keys: select all (Cmd+A) + Cmd+Shift+C.")
            logExec("packFolder", summary)
        case .packSelection:
            pane.compressSelected()
            response = (pane.lastOperationSummary ?? "Packed")
                + (isSwedish ? " Med tangenterna: Cmd+Shift+C." : " With keys: Cmd+Shift+C.")
            logExec("packSelection", response ?? "")
        case .organize(let plan):
            pane.organizeFolder()
            let detail = plan.map { "\($0.count) \($0.category.lowercased())" }.joined(separator: ", ")
            response = (isSwedish ? "Klart — sorterat: " : "Done — sorted: ") + detail + "."
            logExec("organize", detail)
        }
    }

    private func runFind(question: String, original: String) {
        let request = AssistantFind.request(from: question)
        guard !request.isEmpty else {
            onOpenChat(original)
            return
        }
        isBusy = true
        response = isSwedish ? "Letar…" : "Searching…"
        let home = FileManager.default.homeDirectoryForCurrentUser
        var roots: [URL] = [pane.currentURL]
        for name in ["Music", "Documents", "Downloads", "Desktop"] {
            let dir = home.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: dir.path), !roots.contains(dir) {
                roots.append(dir)
            }
        }
        Task.detached(priority: .userInitiated) {
            let results = AssistantFind.search(in: roots, request: request)
            await MainActor.run {
                isBusy = false
                findResults = results
                if results.isEmpty {
                    response = (isSwedish
                        ? "Hittade inget som matchar i den här mappen, Music, Documents, Downloads eller Desktop."
                        : "Found nothing matching in this folder, Music, Documents, Downloads or Desktop.")
                } else {
                    let top = results.prefix(3).map(\.match.url.lastPathComponent).joined(separator: ", ")
                    response = (isSwedish
                        ? "Hittade \(results.count) möjliga träffar. Bäst: \(top). Klicka på en träff för att visa den i panelen."
                        : "Found \(results.count) possible matches. Best: \(top). Click a match to show it in the pane.")
                }
                logExec("find", "\(results.count) results for \(question)")
            }
        }
    }

    private func logExec(_ action: String, _ detail: String) {
        DebugLog.shared.info("gemma.exec", action, context: ["detail": detail, "folder": pane.currentURL.path])
    }
}
