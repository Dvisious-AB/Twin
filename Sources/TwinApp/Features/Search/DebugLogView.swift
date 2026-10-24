import AppKit
import SwiftUI
import TwinCore

/// Debug log viewer: what the app saw when something felt like a
/// dead end. Copy the dump and send it to us — path, error domain
/// and code say what actually happened.
struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [DebugLog.Entry] = []
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "ladybug")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Debug Log").font(.headline)
                    Text(DebugLog.shared.fileURL.path)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button(copied ? "Copied!" : "Copy Log") { copyLog() }
                Button("Clear") {
                    DebugLog.shared.clear()
                    DebugLog.shared.flush()
                    entries = []
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            if entries.isEmpty {
                ContentUnavailableView("No Log Entries Yet", systemImage: "ladybug",
                                       description: Text("Navigate around — loads, failures and recovery actions are recorded here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color(for: entry.level))
                                .frame(width: 7, height: 7)
                            Text(entry.category).font(.caption.bold())
                            Text(entry.message).font(.caption)
                            Spacer()
                            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if !entry.context.isEmpty {
                            Text(entry.context.sorted { $0.key < $1.key }
                                .map { "\($0.key)=\($0.value)" }.joined(separator: "  "))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .onAppear {
            DebugLog.shared.flush()
            entries = DebugLog.shared.entries()
        }
    }

    private func color(for level: DebugLog.Entry.Level) -> Color {
        switch level {
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func copyLog() {
        DebugLog.shared.flush()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DebugLog.shared.textDump(), forType: .string)
        copied = true
    }
}
