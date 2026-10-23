import AppKit
import SwiftUI
import TwinCore
import TwinPro

struct DualPaneView: View {
    @StateObject var leftTabs: PaneTabs
    @StateObject var rightTabs: PaneTabs

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        _leftTabs = StateObject(wrappedValue: PaneTabs(first: home))
        _rightTabs = StateObject(wrappedValue: PaneTabs(first: home.appendingPathComponent("Documents")))
    }

    private var left: PaneViewModel { leftTabs.active }
    private var right: PaneViewModel { rightTabs.active }
    private var activeTabs: PaneTabs { selected == 0 ? leftTabs : rightTabs }
    @State var selected: Int = 0
    @FocusState private var paneFocus: Int?
    @State private var showPaywall = false
    @State private var showEncryptPrompt = false
    @State private var showDeleteConfirm = false
    @State private var passphrase = ""
    @State private var showPermissions = false
    @State private var showAssistant = false
    @State private var showNewFolder = false
    @State private var showRename = false
    @State private var newName = ""
    @State private var showBatchRename = false
    @State private var showSaveWorkspace = false
    @State private var showFolderSync = false
    @State private var workspaceName = ""
    @State private var savedWorkspaces: [Workspace] = WorkspaceStore.shared.load()
    @ObservedObject private var store = StoreKitManager.shared

    private func nameSheet(title: String, prompt: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Text(title).font(.headline)
            TextField(prompt, text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Button("Cancel") { showNewFolder = false; showRename = false }
                Spacer()
                Button(title) { action(); showNewFolder = false; showRename = false }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

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
            Button("New Folder") { newName = "New Folder"; showNewFolder = true }
                .keyboardShortcut("7", modifiers: .command)
                .help("New folder (F7 / Cmd+7)")
            Button("Rename") {
                newName = activePane.selection.first?.lastPathComponent ?? ""
                showRename = true
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(activePane.selection.count != 1)
            .help("Rename selected (Shift+F6 / Cmd+Shift+R)")
            Button("Unpack") { activePane.unpackSelected() }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(!activePane.selectedIsArchive)
                .help("Unpack zip (Alt+F6 / Cmd+Shift+U)")
            Button("Sync") {
                if store.isProUnlocked { showFolderSync = true } else { showPaywall = true }
            }
            .help("Folder Sync to other pane (Pro)")
            Button("Batch Rename") {
                if store.isProUnlocked { showBatchRename = true } else { showPaywall = true }
            }
            .disabled(activePane.selection.isEmpty)
            .help("Batch rename selected (Pro)")
            Menu("Workspaces") {
                Button("Save Current…") {
                    if store.isProUnlocked { workspaceName = ""; showSaveWorkspace = true } else { showPaywall = true }
                }
                if !savedWorkspaces.isEmpty { Divider() }
                ForEach(savedWorkspaces) { workspace in
                    Button(workspace.name) { applyWorkspace(workspace) }
                }
                if !savedWorkspaces.isEmpty {
                    Divider()
                    ForEach(savedWorkspaces) { workspace in
                        Button("Delete \(workspace.name)", role: .destructive) {
                            WorkspaceStore.shared.delete(id: workspace.id)
                            savedWorkspaces = WorkspaceStore.shared.load()
                        }
                    }
                }
            }
            .help("Saved workspaces (Pro)")
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

    private func paneColumn(tabs: PaneTabs, side: Int) -> some View {
        VStack(spacing: 0) {
            tabStrip(tabs: tabs, side: side)
            PaneView(
                viewModel: tabs.active, isActive: selected == side,
                onRequestPaneSwitch: { switchPane() },
                onChooseFolder: { chooseFolder(for: tabs.active) }
            )
            .id(ObjectIdentifier(tabs.active))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focused($paneFocus, equals: side)
            .onTapGesture { selected = side; paneFocus = side }
        }
    }

    private func tabStrip(tabs: PaneTabs, side: Int) -> some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(tabs.tabs.enumerated()), id: \.offset) { index, tab in
                        HStack(spacing: 4) {
                            Button(tab.currentURL.lastPathComponent) {
                                tabs.select(at: index)
                                selected = side
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .lineLimit(1)
                            if tabs.tabs.count > 1 {
                                Button {
                                    tabs.close(at: index)
                                } label: {
                                    Image(systemName: "xmark").font(.caption2)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            index == tabs.activeIndex
                                ? Color.accentColor.opacity(selected == side ? 0.35 : 0.18)
                                : Color.secondary.opacity(0.12)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            Button {
                tabs.newTab()
                selected = side
            } label: {
                Image(systemName: "plus").font(.caption)
            }
            .buttonStyle(.borderless)
            .help("New tab")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func switchPane() {
        selected = selected == 0 ? 1 : 0
        paneFocus = selected
    }

    private func saveWorkspace() {
        let workspace = Workspace(
            name: workspaceName.trimmingCharacters(in: .whitespaces),
            leftTabs: leftTabs.tabs.map { $0.currentURL.path },
            rightTabs: rightTabs.tabs.map { $0.currentURL.path },
            activeLeftTab: leftTabs.activeIndex,
            activeRightTab: rightTabs.activeIndex,
            activeSide: selected
        )
        WorkspaceStore.shared.save(workspace)
        savedWorkspaces = WorkspaceStore.shared.load()
    }

    private func applyWorkspace(_ workspace: Workspace) {
        guard store.isProUnlocked else { showPaywall = true; return }
        leftTabs.restore(paths: workspace.leftTabs, active: workspace.activeLeftTab)
        rightTabs.restore(paths: workspace.rightTabs, active: workspace.activeRightTab)
        selected = workspace.activeSide
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
            paneColumn(tabs: leftTabs, side: 0)
            paneColumn(tabs: rightTabs, side: 1)
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
        .sheet(isPresented: $showNewFolder) {
            nameSheet(title: "New Folder", prompt: "Folder name") {
                activePane.createFolder(named: newName)
            }
        }
        .sheet(isPresented: $showFolderSync) {
            FolderSyncView(source: activePane.currentURL, destination: inactivePane.currentURL) {
                inactivePane.refresh()
            }
        }
        .sheet(isPresented: $showBatchRename) {
            BatchRenameView(items: activePane.selection.sorted(by: { $0.path < $1.path })) {
                activePane.refresh()
            }
        }
        .sheet(isPresented: $showSaveWorkspace) {
            VStack(spacing: 14) {
                Text("Save Workspace").font(.headline)
                TextField("Workspace name", text: $workspaceName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                HStack {
                    Button("Cancel") { showSaveWorkspace = false }
                    Spacer()
                    Button("Save") { saveWorkspace(); showSaveWorkspace = false }
                        .buttonStyle(.borderedProminent)
                        .disabled(workspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
        .sheet(isPresented: $showRename) {
            nameSheet(title: "Rename", prompt: "New name") {
                activePane.renameSelected(to: newName)
            }
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
                Button { activeTabs.newTab() } label: { Label("New Tab", systemImage: "plus.rectangle") }
                    .keyboardShortcut("t", modifiers: .command)
                    .help("New tab in active pane (Cmd+T)")
                Button { activeTabs.closeActive() } label: { Label("Close Tab", systemImage: "xmark.rectangle") }
                    .keyboardShortcut("w", modifiers: .command)
                    .disabled(activeTabs.tabs.count <= 1)
                    .help("Close active tab (Cmd+W)")
                Button { selected = 0; paneFocus = 0 } label: { Label("Left", systemImage: "rectangle.leadinghalf.inset.filled") }
                    .keyboardShortcut("1", modifiers: .command)
                    .help("Activate left pane (Cmd+1)")
                Button { selected = 1; paneFocus = 1 } label: { Label("Right", systemImage: "rectangle.trailinghalf.inset.filled") }
                    .keyboardShortcut("2", modifiers: .command)
                    .help("Activate right pane (Cmd+2)")
                Button { activePane.goToRoot() } label: { Label("Root", systemImage: "house") }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .help("Go to root (TC: Ctrl+\\ — Mac binding Cmd+Option+R, layout-safe)")
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
