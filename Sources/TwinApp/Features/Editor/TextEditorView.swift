import SwiftUI
import TwinCore

/// Minimal built-in text editor (F4 in Total Commander, Cmd+E in Twin).
/// Loads the file as text, Cmd+S / Save writes it back to the same path.
struct TextEditorView: View {
    let url: URL
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.text")
                Text(url.lastPathComponent).font(.headline)
                Text(url.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding(10)
            Divider()
            if let loadError {
                ContentUnavailableView("Can't Edit This File", systemImage: "doc.badge.gearshape", description: Text(loadError))
            } else {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .padding(6)
            }
        }
        .frame(minWidth: 640, minHeight: 440)
        .onAppear(perform: load)
    }

    private func load() {
        do {
            text = try TextFileService.loadText(at: url)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try TextFileService.saveText(text, at: url)
            onSave()
            dismiss()
        } catch {
            loadError = error.localizedDescription
        }
    }
}
