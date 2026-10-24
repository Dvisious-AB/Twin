import AppKit
import SwiftUI
import TwinCore
import TwinPro

struct DualPaneView: View {
    @StateObject var leftTabs: PaneTabs
    @StateObject var rightTabs: PaneTabs

    /// True when nothing has been granted/restored yet — the app then
    /// asks for the home folder once instead of opening the container.
    private let isFirstRun: Bool

    init() {
        // Real start folders, never the sandbox container: left pane
        // home, right pane Desktop (Documents fallback).
        let places = UserPlaces.current
        // A saved session counts only if it points at real folders —
        // older builds saved sandbox-container paths.
        let savedPaths = UserDefaults.standard.stringArray(forKey: "twin.session.left.paths") ?? []
        let hadSession = savedPaths.contains { !$0.contains("/Library/Containers/") }
        let hasHomeBookmark = BookmarkStore.shared.resolveBookmark(for: places.home) != nil
        isFirstRun = !hadSession && !hasHomeBookmark
        _leftTabs = StateObject(wrappedValue: PaneTabs(first: places.home, storageKey: "twin.session.left"))
        _rightTabs = StateObject(wrappedValue: PaneTabs(
            first: places.defaultRightPaneFolder, storageKey: "twin.session.right"
        ))
        _selected = State(initialValue: UserDefaults.standard.integer(forKey: "twin.session.activeSide"))
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
    @State private var showHandlersGuide = false
    @State private var showFileSearch = false
    @State private var showFirstRunGrant = false
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
    /// Primary actions stay visible at any window width; everything
    /// else lives in the explicit "More" menu (UX review 2026-10-23:
    /// a silently scrolling bar hid Delete/Sync from TC users).
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
            Button("F5 Copy") { activePane.startCopy(to: inactivePane.currentURL) }
            .keyboardShortcut("5", modifiers: .command)
            .disabled(activePane.selection.isEmpty)
            Button("F6 Move") { activePane.startMove(to: inactivePane.currentURL) }
            .keyboardShortcut("6", modifiers: .command)
            .disabled(activePane.selection.isEmpty)
            Divider().frame(height: 16)
            Button("F3 View") { activePane.viewSelected() }
                .disabled(activePane.selection.isEmpty)
                .help("View selected file in Twin Viewer (F3)")
            Button("Edit") { activePane.editSelected() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(activePane.selection.isEmpty)
                .help("Edit selected file (F4 / Cmd+E)")
            Button("Pack") { activePane.compressSelected() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(activePane.selection.isEmpty)
                .help("Compress to .zip (Alt+F5 / Cmd+Shift+C)")
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
            Button("Delete") { showDeleteConfirm = true }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(activePane.selection.isEmpty)
                .help("Move to Trash (F8 / Cmd+Delete)")
            Menu("More") {
                Button("MD5") { activePane.createMD5ForSelected() }
                    .disabled(activePane.selection.isEmpty)
                Button("Encrypt / Decrypt…") { showEncryptPrompt = true }
                    .disabled(activePane.selection.isEmpty)
                Button("Unpack") { activePane.unpackSelected() }
                    .disabled(!activePane.selectedIsArchive)
                Divider()
                Button("Folder Sync… (Pro)") {
                    if store.isProUnlocked { showFolderSync = true } else { showPaywall = true }
                }
                Button("Batch Rename… (Pro)") {
                    if store.isProUnlocked { showBatchRename = true } else { showPaywall = true }
                }
                .disabled(activePane.selection.isEmpty)
                Menu("Workspaces (Pro)") {
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
                Divider()
                Button("Permissions…") { showPermissions = true }
                    .disabled(activePane.selection.count != 1)
                Button("Find Files…") { showFileSearch = true }
                Button("File Type Handlers…") { showHandlersGuide = true }
                Button("Assistant…") { showAssistant = true }
            }
            .help("More actions")
        }
        // Docked full-width bar: folder pair pinned left, actions
        // pinned right via the Spacer — also in fullscreen.
        .frame(maxWidth: .infinity)
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
                onChooseFolder: { chooseFolder(for: tabs.active) },
                onActivate: { selected = side; paneFocus = side },
                onGrantAccess: { grantAccess(for: tabs.active) },
                onConfigureHandlers: { showHandlersGuide = true }
            )
            .id(ObjectIdentifier(tabs.active))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // No .focused here: a second focus binding on the column
            // stole the keyboard from the pane's Table (dead arrows).
            // Activation flows through isActive → listFocused instead.
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
                            .accessibilityIdentifier("paneTab")
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

    /// Re-grants access to the folder a pane is failing to read
    /// (error-state recovery): picker starts at that exact folder;
    /// choosing it saves the bookmark and reloads.
    private func grantAccess(for pane: PaneViewModel) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Grant Twin access to \(pane.currentURL.lastPathComponent) to read it again."
        panel.directoryURL = pane.currentURL
        if panel.runModal() == .OK, let url = panel.url {
            pane.navigate(to: url)
        }
    }

    /// Navigates to a known place, asking for access first when the
    /// sandbox cannot read it yet (bookmark grant via open panel).
    private func navigateOrGrant(to url: URL, for pane: PaneViewModel) {
        if (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil {
            pane.navigate(to: url)
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Grant Twin access to \(url.lastPathComponent). macOS remembers this via a bookmark."
        panel.directoryURL = url
        if panel.runModal() == .OK, let granted = panel.url {
            pane.navigate(to: granted)
        }
    }

    /// First-run: one explicit grant of the home folder, then the
    /// panes start at home (left) and Desktop (right) forever after.
    private func grantHomeFolder() {
        let places = UserPlaces.current
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Choose your home folder. Twin bookmarks it and starts there next time — no sandbox container."
        panel.directoryURL = places.home
        if panel.runModal() == .OK, let url = panel.url {
            left.navigate(to: url)
            right.navigate(to: places.defaultRightPaneFolder)
        }
        showFirstRunGrant = false
    }

    private var activePane: PaneViewModel { selected == 0 ? left : right }
    private var inactivePane: PaneViewModel { selected == 0 ? right : left }

    /// Publishes the active pane's actions to the TC-style menu bar.
    private func syncMenuBridge() {
        let bridge = AppMenuBridge.shared
        bridge.hasSelection = !activePane.selection.isEmpty
        bridge.singleSelection = activePane.selection.count == 1
        bridge.archiveSelected = activePane.selectedIsArchive
        bridge.canCloseTab = activeTabs.tabs.count > 1
        bridge.proUnlocked = store.isProUnlocked
        bridge.copy = { activePane.startCopy(to: inactivePane.currentURL) }
        bridge.move = { activePane.startMove(to: inactivePane.currentURL) }
        bridge.view = { activePane.viewSelected() }
        bridge.handlersGuide = { showHandlersGuide = true }
        bridge.edit = { activePane.editSelected() }
        bridge.pack = { activePane.compressSelected() }
        bridge.unpack = { activePane.unpackSelected() }
        bridge.md5 = { activePane.createMD5ForSelected() }
        bridge.encrypt = { showEncryptPrompt = true }
        bridge.newFolder = { newName = "New Folder"; showNewFolder = true }
        bridge.rename = {
            newName = activePane.selection.first?.lastPathComponent ?? ""
            showRename = true
        }
        bridge.delete = { showDeleteConfirm = true }
        bridge.permissions = { showPermissions = true }
        bridge.assistant = { showAssistant = true }
        bridge.folderSync = {
            if store.isProUnlocked { showFolderSync = true } else { showPaywall = true }
        }
        bridge.batchRename = {
            if store.isProUnlocked { showBatchRename = true } else { showPaywall = true }
        }
        bridge.focusFilter = { activePane.focusSearch() }
        bridge.findFiles = { showFileSearch = true }
        bridge.setListView = { activePane.viewMode = .list }
        bridge.setIconView = { activePane.viewMode = .icon }
        bridge.newTab = { activeTabs.newTab() }
        bridge.closeTab = { activeTabs.closeActive() }
        let places = UserPlaces.current
        bridge.iCloudAvailable = places.iCloudDrive != nil
        bridge.goHome = { navigateOrGrant(to: places.home, for: activePane) }
        bridge.goDesktop = { navigateOrGrant(to: places.desktop, for: activePane) }
        bridge.goDocuments = { navigateOrGrant(to: places.documents, for: activePane) }
        bridge.goDownloads = { navigateOrGrant(to: places.downloads, for: activePane) }
        bridge.goICloud = {
            if let drive = places.iCloudDrive { navigateOrGrant(to: drive, for: activePane) }
        }
    }

    /// Real Total Commander function keys (F4/F5/F6/F7/F8). SwiftUI has
    /// no F-key equivalents, so an AppKit key monitor handles them —
    /// the button labels promised F5/F6 (UX review 2026-10-23, P0-3).
    /// Returns true when the key was consumed.
    private func handleFunctionKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 99: // F3
            guard !activePane.selection.isEmpty else { return false }
            activePane.viewSelected()
        case 118: // F4
            guard !activePane.selection.isEmpty else { return false }
            activePane.editSelected()
        case 96: // F5
            guard !activePane.selection.isEmpty else { return false }
            activePane.startCopy(to: inactivePane.currentURL)
        case 97: // F6
            guard !activePane.selection.isEmpty else { return false }
            activePane.startMove(to: inactivePane.currentURL)
        case 98: // F7
            newName = "New Folder"
            showNewFolder = true
        case 100: // F8
            guard !activePane.selection.isEmpty else { return false }
            showDeleteConfirm = true
        default:
            return false
        }
        return true
    }

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
        .background(FunctionKeyHandler { handleFunctionKey($0) })
        .onAppear {
            syncMenuBridge()
            if isFirstRun { showFirstRunGrant = true }
        }
        .onChange(of: selected) { _, side in
            UserDefaults.standard.set(side, forKey: "twin.session.activeSide")
            syncMenuBridge()
        }
        .onChange(of: activePane.selection) { _, _ in syncMenuBridge() }
        .onChange(of: activePane.currentURL) { _, _ in syncMenuBridge() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showPermissions) {
            if let url = activePane.selection.first {
                PermissionsView(url: url) { activePane.refresh() }
            }
        }
        .sheet(isPresented: $showAssistant) {
            AssistantView(viewModel: activePane)
        }
        .sheet(isPresented: $showHandlersGuide) {
            FileHandlersSettingsView()
        }
        .sheet(isPresented: $showFileSearch) {
            FileSearchView(
                root: activePane.currentURL,
                onReveal: { url in activePane.revealResult(url) },
                onOpen: { url in activePane.openResult(url) }
            )
        }
        .sheet(isPresented: $showFirstRunGrant) {
            VStack(spacing: 14) {
                Text("Welcome to Twin").font(.title3.bold())
                Text("Twin starts in your home folder (left) and Desktop (right). "
                    + "macOS asks you to grant the home folder once — Twin bookmarks it "
                    + "and never opens its sandbox container again.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380)
                Button("Choose Home Folder…") { grantHomeFolder() }
                    .keyboardShortcut(.defaultAction)
                Button("Later") { showFirstRunGrant = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(24)
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
            Text(activePane.selection.count == 1
                ? "1 item will be moved to the Trash."
                : "\(activePane.selection.count) items will be moved to the Trash.")
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
                // F5/F6 live in the function bar only (no duplication),
                // and Pro is not a permanent crown in the toolbar —
                // locked Pro features surface the paywall from More
                // (UX review P1-9).
            }
        }
    }
}

/// AppKit bridge for the function keys SwiftUI cannot express.
/// Installs a local key-down monitor for F4–F8 (no command/control/
/// option modifiers) and never steals keys from text editing, so the
/// filter field and sheet text fields keep their keys.
private struct FunctionKeyHandler: NSViewRepresentable {
    let onFunctionKey: (UInt16) -> Bool

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install(onFunctionKey: onFunctionKey)
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onFunctionKey = onFunctionKey
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onFunctionKey: ((UInt16) -> Bool)?
        private var monitor: Any?

        func install(onFunctionKey: @escaping (UInt16) -> Bool) {
            self.onFunctionKey = onFunctionKey
            let functionKeyCodes: Set<UInt16> = [118, 96, 97, 98, 100] // F4 F5 F6 F7 F8
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, functionKeyCodes.contains(event.keyCode) else { return event }
                guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                if NSApp.keyWindow?.firstResponder is NSText { return event }
                return self.onFunctionKey?(event.keyCode) == true ? nil : event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
