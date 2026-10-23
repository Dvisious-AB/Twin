import TwinCore
import SwiftUI

/// Beginner-friendly permissions editor: who may read, write, execute —
/// with presets for common cases and octal shown for advanced users.
struct PermissionsView: View {
    let url: URL
    var onApply: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var permissions = FilePermissions(octal: 0o644)
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: url.hasDirectoryPath ? "folder.fill" : "doc")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(url.lastPathComponent).font(.headline)
                    Text(url.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    Text("Read").font(.caption.bold())
                    Text("Write").font(.caption.bold())
                    Text("Open/Run").font(.caption.bold())
                }
                Divider()
                triadRow("Owner (you)", value: $permissions.owner)
                triadRow("Group", value: $permissions.group)
                triadRow("Everyone else", value: $permissions.others)
            }

            HStack {
                Text("Presets:")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Preset", selection: $permissions) {
                    ForEach(FilePermissionService.presets, id: \.name) { preset in
                        Text(preset.name).tag(preset.value)
                    }
                }
                .labelsHidden()
                Spacer()
                Text(permissions.symbolic)
                    .font(.system(.body, design: .monospaced))
                Text(permissions.octalString)
                    .font(.system(.body, design: .monospaced).bold())
            }

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply") { apply() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            permissions = (try? FilePermissionService.permissions(for: url)) ?? FilePermissions(octal: 0o644)
        }
    }

    private func triadRow(_ label: String, value: Binding<Int>) -> some View {
        GridRow {
            Text(label)
            Toggle("", isOn: bit(value, 4)).labelsHidden()
            Toggle("", isOn: bit(value, 2)).labelsHidden()
            Toggle("", isOn: bit(value, 1)).labelsHidden()
        }
    }

    private func bit(_ value: Binding<Int>, _ mask: Int) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue & mask != 0 },
            set: { on in value.wrappedValue = on ? value.wrappedValue | mask : value.wrappedValue & ~mask }
        )
    }

    private func apply() {
        do {
            try FilePermissionService.setPermissions(permissions, for: url)
            onApply()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
