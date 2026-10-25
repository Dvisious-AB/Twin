import SwiftUI
import TwinCore

/// The tail of everything Twin has done — and the way back.
/// Every file operation is journaled by TwinCore; this view lists
/// the journal newest-first and can undo/redo each entry. Undo is
/// never destructive: copies and created files go to Trash, moves
/// go home, trashed items come back from Trash.
struct OperationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var journal = OperationJournal.shared
    /// Called after an undo/redo so the panes can refresh.
    var onChanged: (String) -> Void = { _ in }
    @State private var lastReport: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                Text("History").font(.headline)
                Text("Everything Twin has done — undo anything.")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button("Clear Log") { journal.clear() }
                    .disabled(journal.entries.isEmpty)
                    .help("Clears the log only — files are not touched")
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            if journal.entries.isEmpty {
                ContentUnavailableView(
                    "Nothing yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Copies, moves, renames, organize runs and deletions will appear here — and can be undone.")
                )
            } else {
                List {
                    ForEach(journal.entries.reversed()) { entry in
                        row(entry)
                    }
                }
                .listStyle(.inset)
            }
            if let lastReport {
                Divider()
                Text(lastReport)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
            Divider()
            HStack {
                Text("Log file: \(journal.journalFileURL.lastPathComponent) in Application Support/Twin")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("⌘Z undo · ⇧⌘Z redo")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.bar)
        }
        .frame(minWidth: 560, minHeight: 440)
    }

    private func row(_ entry: OperationRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.symbolName)
                .foregroundStyle(entry.undone ? .secondary : Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.callout.weight(entry.undone ? .regular : .medium))
                    .strikethrough(entry.undone)
                    .lineLimit(2)
                Text("\(entry.date.formatted(date: .abbreviated, time: .shortened)) · \(entry.itemCount) item(s)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if entry.undone {
                Label("Undone", systemImage: "checkmark")
                    .font(.caption2).foregroundStyle(.secondary)
                if entry.redoable {
                    Button("Redo") { apply(journal.redo(entry)) }
                        .accessibilityIdentifier("historyRedoButton")
                }
            } else if entry.undoable {
                Button("Undo") { apply(journal.undo(entry)) }
                    .accessibilityIdentifier("historyUndoButton")
            } else {
                Text("Can't be undone")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func apply(_ report: UndoReport) {
        lastReport = report.summary
        onChanged(report.summary)
    }
}
