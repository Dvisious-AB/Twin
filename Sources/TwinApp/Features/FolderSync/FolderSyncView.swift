import SwiftUI
import TwinCore

/// Folder Sync (Pro): compare active pane (source) with the other pane
/// (destination), then sync. Mirror-delete is off unless explicitly enabled.
struct FolderSyncView: View {
    let source: URL
    let destination: URL
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var plan: [FolderSyncService.SyncEntry] = []
    @State private var mirrorDelete = false
    @State private var resultText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Folder Sync").font(.title3.bold())
            HStack(spacing: 6) {
                Text(source.lastPathComponent).bold().lineLimit(1)
                Image(systemName: "arrow.right")
                Text(destination.lastPathComponent).lineLimit(1)
                Spacer()
                Button("Recompare") { recompute() }
            }
            .font(.callout)

            if plan.isEmpty {
                ContentUnavailableView("Folders Are in Sync", systemImage: "checkmark.circle")
            } else {
                List(plan) { entry in
                    HStack {
                        Image(systemName: icon(for: entry.state))
                            .foregroundStyle(color(for: entry.state))
                        Text(entry.relativePath).lineLimit(1)
                        Spacer()
                        Text(label(for: entry.state))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 220)
            }

            Toggle("Mirror: move extra destination files to Trash", isOn: $mirrorDelete)
                .font(.callout)

            if let resultText {
                Text(resultText).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Sync Now") { runSync() }
                    .buttonStyle(.borderedProminent)
                    .disabled(plan.allSatisfy { $0.state == .same })
            }
        }
        .padding(20)
        .frame(width: 540)
        .onAppear(perform: recompute)
    }

    private func recompute() {
        plan = FolderSyncService.compare(source: source, destination: destination)
    }

    private func runSync() {
        do {
            let result = try FolderSyncService.sync(
                source: source, destination: destination, deleteExtras: mirrorDelete
            )
            resultText = "Copied \(result.copied), deleted \(result.deleted), already same \(result.skippedSame)."
            recompute()
            onDone()
        } catch {
            resultText = error.localizedDescription
        }
    }

    private func icon(for state: FolderSyncService.SyncState) -> String {
        switch state {
        case .onlyInSource: return "plus.circle"
        case .onlyInDestination: return "minus.circle"
        case .different: return "exclamationmark.circle"
        case .same: return "equal.circle"
        }
    }

    private func color(for state: FolderSyncService.SyncState) -> Color {
        switch state {
        case .onlyInSource: return .green
        case .onlyInDestination: return .orange
        case .different: return .red
        case .same: return .secondary
        }
    }

    private func label(for state: FolderSyncService.SyncState) -> String {
        switch state {
        case .onlyInSource: return "only here"
        case .onlyInDestination: return "only in target"
        case .different: return "different"
        case .same: return "same"
        }
    }
}
