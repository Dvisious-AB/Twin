import AppKit
import SwiftUI

struct DualPaneView: View {
    @StateObject var left = PaneViewModel(initialPath: FileManager.default.homeDirectoryForCurrentUser)
    @StateObject var right = PaneViewModel(
        initialPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    )
    @State var selected: Int = 0
    @FocusState private var paneFocus: Int?
    @State private var showPaywall = false
    @State private var showEncryptPrompt = false
    @State private var showDeleteConfirm = false
    @State private var passphrase = ""
    @State private var showPermissions = false
    @State private var showAssistant = false
    @ObservedObject private var store = StoreKitManager.shared

    /// Total Commander-style function bar: the pane operations live here,
    /// always visible, instead of only in the top toolbar.
    private var functionBar: some View {
        HStack(spacing: 8) {
            Text(activePane.currentURL.lastPathComponent)
                .font(.caption.bold())
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(inactivePane.currentURL.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("F5 Copy") {
                Task { await activePane.copySelected(to: inactivePane.currentURL); inactivePane.refresh() }
            }
            .keyboardShortcut("5", modifiers: .command)
            .disabled(activePane.selection.isEmpty)
            Button("F6 Move") {
                Task { await activePane.moveSelected(to: inactivePane.currentURL); inactivePane.refresh() }
            }
            .keyboardShortcut("6", modifiers: .command)
            .disabled(activePane.selection.isEmpty)
            Divider().frame(height: 16)
            Button("Edit") { activePane.editSelected() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(activePane.selection.isEmpty)
                .help("Edit selected file (F4 / Cmd+E)")
            Button("Pack") { activePane.compressSelected() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(activePane.selection.isEmpty)
                .help("Compress to .zip (Alt+F5 / Cmd+Shift+C)")
            Button("MD5") { activePane.createMD5ForSelected() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(activePane.selection.isEmpty)
                .help("Create .md5 checksum file (Cmd+Shift+M)")
            Button("Encrypt") { showEncryptPrompt = true }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(activePane.selection.isEmpty)
                .help("Encrypt/decrypt with passphrase (Cmd+Shift+E)")
            Button("Permissions") { showPermissions = true }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(activePane.selection.count != 1)
                .help("Permissions for selected item (Cmd+I)")
            Button { showAssistant = true } label: {
                Label("Assistant", systemImage: "sparkles")
            }
            .help("Organize and help (on-device)")
            Button("Delete") { showDeleteConfirm = true }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(activePane.selection.isEmpty)
                .help("Move to Trash (F8 / Cmd+Delete)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func switchPane() {
        selected = selected == 0 ? 1 : 0
        paneFocus = selected
    }

    private func chooseFolder(for pane: PaneViewModel) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a folder for this pane. Twin remembers it via a bookmark."
        panel.directoryURL = URL(fileURLWithPath: "/Users")
        if panel.runModal() == .OK, let url = panel.url {
            pane.navigate(to: url)
        }
    }

    private var activePane: PaneViewModel { selected == 0 ? left : right }
    private var inactivePane: PaneViewModel { selected == 0 ? right : left }

    var body: some View {
        VStack(spacing: 0) {
        // NOTE: NavigationStack inside HSplitView collapsed the layout to a
        // centered band and leaked the folder name as window title — removed.
        // Each pane keeps its own navigation state in its view model.
        HSplitView {
            PaneView(
                    viewModel: left, isActive: selected == 0,
                    onRequestPaneSwitch: { switchPane() },
                    onChooseFolder: { chooseFolder(for: left) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focused($paneFocus, equals: 0)
                .onTapGesture { selected = 0; paneFocus = 0 }
            PaneView(
                    viewModel: right, isActive: selected == 1,
                    onRequestPaneSwitch: { switchPane() },
                    onChooseFolder: { chooseFolder(for: right) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focused($paneFocus, equals: 1)
                .onTapGesture { selected = 1; paneFocus = 1 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            functionBar
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showPermissions) {
            if let url = activePane.selection.first {
                PermissionsView(url: url) { activePane.refresh() }
            }
        }
        .sheet(isPresented: $showAssistant) {
            AssistantView(viewModel: activePane)
        }
        .sheet(isPresented: $showEncryptPrompt) {
            VStack(spacing: 14) {
                Text("Encrypt / Decrypt").font(.headline)
                Text("AES-GCM with a key from your passphrase. A .twinenc file is decrypted, anything else is encrypted.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                SecureField("Passphrase", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { showEncryptPrompt = false; passphrase = "" }
                    Spacer()
                    Button("Run") {
                        let secret = passphrase
                        passphrase = ""
                        showEncryptPrompt = false
                        activePane.encryptSelected(passphrase: secret)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(passphrase.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 340)
        }
        .alert("Move to Trash?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) { activePane.trashSelected() }
        } message: {
            Text("\(activePane.selection.count) item(s) will be moved to the Trash.")
        }
        .onOpenURL { url in
            // twin://open?path=/some/folder  (from FinderSync "Open in Twin")
            guard url.scheme == "twin",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let path = components.queryItems?.first(where: { $0.name == "path" })?.value,
                  !path.isEmpty else { return }
            left.navigate(to: URL(fileURLWithPath: path))
            selected = 0
        }
        .toolbar {
            ToolbarItemGroup {
                Button { selected = 0; paneFocus = 0 } label: { Label("Left", systemImage: "rectangle.leadinghalf.inset.filled") }
                    .keyboardShortcut("1", modifiers: .command)
                    .help("Activate left pane (Cmd+1)")
                Button { selected = 1; paneFocus = 1 } label: { Label("Right", systemImage: "rectangle.trailinghalf.inset.filled") }
                    .keyboardShortcut("2", modifiers: .command)
                    .help("Activate right pane (Cmd+2)")
                Button { activePane.focusSearch() } label: { Label("Filter", systemImage: "magnifyingglass") }
                    .keyboardShortcut("f", modifiers: .command)
                    .help("Filter active pane (Cmd+F)")
                Button {
                    Task { await activePane.copySelected(to: inactivePane.currentURL); inactivePane.refresh() }
                } label: { Label("F5 Copy", systemImage: "doc.on.doc") }
                .keyboardShortcut("5", modifiers: .command)
                .help("Copy selected to other pane (F5 / Cmd+5)")

                Button { showPaywall = true } label: { Label(store.isProUnlocked ? "Twin Pro ✓" : "Twin Pro", systemImage: "crown") }
                    .help("Twin Pro — Workspaces, Folder Sync, Batch Rename, Git badges")
                Button {
                    Task { await activePane.moveSelected(to: inactivePane.currentURL); inactivePane.refresh() }
                } label: { Label("F6 Move", systemImage: "arrow.right.doc.on.clipboard") }
                .keyboardShortcut("6", modifiers: .command)
                .help("Move selected to other pane (F6 / Cmd+6)")
            }
        }
    }
}
