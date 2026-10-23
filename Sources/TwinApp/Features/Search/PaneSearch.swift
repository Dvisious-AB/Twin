import SwiftUI

/// Instant per-pane search: pure filter + field view.
/// Empty query returns items unchanged; matching is case/diacritic-insensitive.
enum PaneSearch {
    static func filter(_ items: [FileItem], query: String) -> [FileItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

struct PaneSearchField: View {
    @Binding var text: String
    var onFocusChange: (Bool) -> Void = { _ in }
    var focusTrigger: Int = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Filter…", text: $text)
                .textFieldStyle(.plain)
                .font(.caption)
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in onFocusChange(focused) }
                .onChange(of: focusTrigger) { _, _ in isFocused = true }
                .onExitCommand { text = ""; isFocused = false }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }
}
