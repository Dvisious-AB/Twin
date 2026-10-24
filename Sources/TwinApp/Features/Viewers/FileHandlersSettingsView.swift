import AppKit
import SwiftUI
import TwinCore

/// Guide: connect a file type to a viewer/editor and override the
/// macOS default *inside Twin* (Enter/F4 honour it; F3 is View).
/// Also where users build their own handlers — an app or a command
/// template like `/usr/local/bin/hexfiend {file}`.
struct FileHandlersSettingsView: View {
    private enum Pick: Hashable {
        case inherit, twinViewer, twinEditor, system, external, custom(String)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var revision = 0 // bumps to re-read the store
    @State private var selectedExt = "md"
    @State private var customExt = ""
    @State private var viewerPick: Pick = .inherit
    @State private var editorPick: Pick = .inherit
    @State private var viewerApp: URL?
    @State private var editorApp: URL?
    @State private var status: String?

    // New custom handler form
    @State private var newName = ""
    @State private var newExts = ""
    @State private var newUseCommand = false
    @State private var newApp: URL?
    @State private var newCommand = ""

    private var store: FileHandlerStore { .shared }
    private var kind: FileKind { FileTypeRegistry.kind(forExtension: selectedExt) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                Text("File Type Handlers").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    step1Type
                    step2Viewer
                    step3Editor
                    summaryAndSave
                    customHandlersSection
                    macDefaultSection
                    if let status {
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 620, minHeight: 560)
        .onAppear { loadAssociation() }
        .onChange(of: selectedExt) { _, _ in loadAssociation() }
    }

    // MARK: - Step 1: file type

    private var step1Type: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. Choose a file type").font(.subheadline.bold())
            HStack(spacing: 8) {
                Picker("Type", selection: $selectedExt) {
                    ForEach(FileTypeRegistry.knownExtensions, id: \.self) { ext in
                        Text(".\(ext) — \(FileTypeRegistry.kind(forExtension: ext).label)")
                            .tag(ext)
                    }
                }
                .labelsHidden()
                .frame(width: 260)
                TextField("or type: log, dat…", text: $customExt)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .onSubmit { applyCustomExt() }
                Button("Use") { applyCustomExt() }
                    .disabled(customExt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            let existing = store.associations
                .filter { !$0.value.isEmpty }
                .sorted { $0.key < $1.key }
            if !existing.isEmpty {
                Text("Your overrides: " + existing.map { ".\($0.key)" }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func applyCustomExt() {
        let ext = FileTypeRegistry.normalizedExtension(customExt)
        guard !ext.isEmpty else { return }
        selectedExt = ext
        customExt = ""
    }

    // MARK: - Steps 2/3: viewer + editor pickers

    private func choicePicker(title: String, pick: Binding<Pick>, app: Binding<URL?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold())
            Picker(title, selection: pick) {
                Text("Twin standard for \(kind.label)").tag(Pick.inherit)
                Text("Twin Viewer (inbyggd)").tag(Pick.twinViewer)
                if kind.isTextEditable {
                    Text("Twin Editor (inbyggd)").tag(Pick.twinEditor)
                }
                Text("Extern app…").tag(Pick.external)
                ForEach(store.customHandlers) { handler in
                    Text("Egen: \(handler.name)").tag(Pick.custom(handler.id))
                }
                Text("macOS standardapp").tag(Pick.system)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)
            if pick.wrappedValue == .external {
                externalAppRow(app: app)
            }
        }
    }

    private func externalAppRow(app: Binding<URL?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let chosen = app.wrappedValue {
                    Text(FileLauncher.appName(for: chosen)).font(.caption.bold())
                    Text(chosen.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("No app chosen yet").font(.caption).foregroundStyle(.orange)
                }
                Button("Choose App…") { chooseApp(into: app) }
            }
            let candidates = FileLauncher.applications(forExtension: selectedExt)
            if !candidates.isEmpty {
                HStack(spacing: 6) {
                    Text("Can open .\(selectedExt):").font(.caption2).foregroundStyle(.secondary)
                    ForEach(candidates.prefix(5), id: \.path) { candidate in
                        Button(FileLauncher.appName(for: candidate)) { app.wrappedValue = candidate }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var step2Viewer: some View {
        choicePicker(title: "2. View (F3) — visar filen", pick: $viewerPick, app: $viewerApp)
    }

    private var step3Editor: some View {
        VStack(alignment: .leading, spacing: 4) {
            choicePicker(title: "3. Edit / Open (F4 och Enter)", pick: $editorPick, app: $editorApp)
            Text("Enter och dubbelklick följer editor-valet. Det är så du åsidosätter macOS standardapp — i Twin.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Summary + save

    private var summaryAndSave: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summaryText).font(.callout)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("Reset .\(selectedExt)") {
                    store.setAssociation(FileTypeAssociation(), forExtension: selectedExt)
                    loadAssociation()
                    status = ".\(selectedExt) is back to Twin/macOS defaults."
                }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
    }

    private var summaryText: String {
        "F3 visar .\(selectedExt) med \(describe(viewerPick, app: viewerApp)). "
            + "F4/Enter öppnar med \(describe(editorPick, app: editorApp))."
    }

    private func describe(_ pick: Pick, app: URL?) -> String {
        switch pick {
        case .inherit:
            return kind.hasBuiltinViewer || kind.isTextEditable
                ? "Twin standard (\(kind.label))" : "macOS standardapp"
        case .twinViewer: return "Twin Viewer"
        case .twinEditor: return "Twin Editor"
        case .system: return "macOS standardapp"
        case .external: return app.map(FileLauncher.appName(for:)) ?? "en extern app (välj den först)"
        case .custom(let id):
            return store.customHandler(id: id).map { "din handler \($0.name)" } ?? "en egen handler"
        }
    }

    private var canSave: Bool {
        if viewerPick == .external, viewerApp == nil { return false }
        if editorPick == .external, editorApp == nil { return false }
        return true
    }

    // MARK: - Custom handlers ("build your own")

    private var customHandlersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Build your own viewer/editor").font(.subheadline.bold())
            Text("En egen handler är ett program eller ett kommando som får filen. "
                + "Exempel-kommando: /usr/local/bin/hexfiend {file} — {file} byts mot filsökvägen.")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(store.customHandlers) { handler in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(handler.name).font(.caption.bold())
                        Text(handler.extensions.map { ".\($0)" }.joined(separator: " ")
                            + " · " + (handler.applicationPath.map { FileLauncher.appName(for: URL(fileURLWithPath: $0)) }
                                ?? handler.commandTemplate ?? ""))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button("Delete", role: .destructive) {
                        store.removeCustomHandler(id: handler.id)
                        revision += 1
                        status = "Deleted handler \(handler.name)."
                    }
                    .font(.caption)
                }
            }
            HStack(spacing: 8) {
                TextField("Name, e.g. Hex Fiend", text: $newName).frame(width: 170)
                TextField("Extensions: bin, dat", text: $newExts).frame(width: 160)
            }
            .textFieldStyle(.roundedBorder)
            Picker("Kind", selection: $newUseCommand) {
                Text("App").tag(false)
                Text("Command").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            if newUseCommand {
                TextField("/path/to/tool {file}", text: $newCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            } else {
                HStack(spacing: 8) {
                    Text(newApp.map(FileLauncher.appName(for:)) ?? "No app chosen")
                        .font(.caption).foregroundStyle(newApp == nil ? .orange : .primary)
                    Button("Choose App…") { chooseApp(into: $newApp) }
                }
            }
            Button("Add Custom Handler") { addCustomHandler() }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty
                    || newExts.trimmingCharacters(in: .whitespaces).isEmpty
                    || (newUseCommand ? newCommand.isEmpty : newApp == nil))
            Text("Den nya handlern kopplas direkt som editor för sina filtyper och går att välja i steg 2–3.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var macDefaultSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("macOS standardapp").font(.subheadline.bold())
            Text("Guiden ovan styr Twin. Om du även vill att Finder ska öppna .\(selectedExt) i Twin "
                + "kan du försöka sätta det här — macOS kan neka när appen är sandboxad.")
                .font(.caption2).foregroundStyle(.secondary)
            Button("Set Twin as macOS Default for .\(selectedExt)…") {
                status = FileLauncher.trySetTwinAsMacDefault(forExtension: selectedExt)
            }
        }
    }

    // MARK: - Actions

    private func loadAssociation() {
        let association = store.association(forExtension: selectedExt)
        (viewerPick, viewerApp) = unpack(association.viewer)
        (editorPick, editorApp) = unpack(association.editor)
    }

    private func unpack(_ choice: HandlerChoice?) -> (Pick, URL?) {
        switch choice {
        case nil: return (.inherit, nil)
        case .twinViewer: return (.twinViewer, nil)
        case .twinEditor: return (.twinEditor, nil)
        case .systemDefault: return (.system, nil)
        case .externalApp(let path, _): return (.external, URL(fileURLWithPath: path))
        case .customHandler(let id): return (.custom(id), nil)
        }
    }

    private func pack(_ pick: Pick, app: URL?) -> HandlerChoice? {
        switch pick {
        case .inherit: return nil
        case .twinViewer: return .twinViewer
        case .twinEditor: return .twinEditor
        case .system: return .systemDefault
        case .external:
            guard let app else { return nil }
            return .externalApp(path: app.path, name: FileLauncher.appName(for: app))
        case .custom(let id): return .customHandler(id: id)
        }
    }

    private func save() {
        store.setAssociation(
            FileTypeAssociation(viewer: pack(viewerPick, app: viewerApp),
                                editor: pack(editorPick, app: editorApp)),
            forExtension: selectedExt)
        revision += 1
        status = "Saved. .\(selectedExt): \(summaryText)"
    }

    private func addCustomHandler() {
        let exts = newExts.split(separator: ",").map { FileTypeRegistry.normalizedExtension(String($0)) }
            .filter { !$0.isEmpty }
        let handler = CustomHandler(
            name: newName.trimmingCharacters(in: .whitespaces),
            extensions: exts,
            applicationPath: newUseCommand ? nil : newApp?.path,
            commandTemplate: newUseCommand ? newCommand : nil)
        store.upsertCustomHandler(handler)
        newName = ""; newExts = ""; newCommand = ""; newApp = nil
        revision += 1
        status = "Handler \(handler.name) added and set as editor for \(exts.map { ".\($0)" }.joined(separator: ", "))."
    }

    private func chooseApp(into binding: Binding<URL?>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the app that should open this file type."
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url
        }
    }
}
