import SwiftUI
import TwinCore

/// Batch rename (Pro) with live preview: find/replace, prefix/suffix,
/// optional numbering. Nothing is renamed until Apply.
struct BatchRenameView: View {
    let items: [URL]
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var find = ""
    @State private var replace = ""
    @State private var prefix = ""
    @State private var suffix = ""
    @State private var numbering = false
    @State private var errorText: String?
    @FocusState private var findFocused: Bool

    private var rule: FileActionService.BatchRenameRule {
        var rule = FileActionService.BatchRenameRule()
        rule.find = find
        rule.replace = replace
        rule.prefix = prefix
        rule.suffix = suffix
        rule.addNumbering = numbering
        return rule
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Batch Rename").font(.title3.bold())
                .onAppear { findFocused = true }
            Text("\(items.count) item(s) selected").font(.caption).foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Find")
                    TextField("text to replace", text: $find)
                        .textFieldStyle(.roundedBorder)
                        .focused($findFocused)
                    Text("Replace")
                    TextField("with", text: $replace).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Prefix")
                    TextField("before name", text: $prefix).textFieldStyle(.roundedBorder)
                    Text("Suffix")
                    TextField("after name", text: $suffix).textFieldStyle(.roundedBorder)
                }
            }
            Toggle("Add numbering (… 1, … 2)", isOn: $numbering)

            Text("Preview").font(.headline)
            List {
                ForEach(Array(items.enumerated()), id: \.offset) { index, url in
                    HStack {
                        Text(url.lastPathComponent).foregroundStyle(.secondary).lineLimit(1)
                        Image(systemName: "arrow.right").font(.caption2)
                        Text(FileActionService.renamedName(for: url, rule: rule, index: index)).lineLimit(1)
                    }
                    .font(.callout)
                }
            }
            .frame(height: 160)

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Rename \(items.count) Item(s)") { apply() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func apply() {
        do {
            _ = try FileActionService.batchRename(items: items, rule: rule)
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
