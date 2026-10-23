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
    @ObservedObject private var store = StoreKitManager.shared
    @AppStorage("twin.didPickStartFolder") private var didPickStartFolder = false

    private func switchPane() {
        selected = selected == 0 ? 1 : 0
        paneFocus = selected
    }

    /// Sandboxed apps see their container as "home". On first launch, let the
    /// user pick their real start folder once; the choice is bookmarked.
    private func pickStartFolderIfNeeded() {
        guard !didPickStartFolder else { return }
        didPickStartFolder = true
        guard left.currentURL.path.contains("/Library/Containers/") else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Start Folder"
        panel.message = "Choose your start folder (for example your home folder). Twin remembers it."
        panel.directoryURL = URL(fileURLWithPath: "/Users")
        if panel.runModal() == .OK, let url = panel.url {
            left.navigate(to: url)
            let documents = url.appendingPathComponent("Documents")
            if FileManager.default.fileExists(atPath: documents.path) {
                right.navigate(to: documents)
            }
        }
    }

    private var activePane: PaneViewModel { selected == 0 ? left : right }
    private var inactivePane: PaneViewModel { selected == 0 ? right : left }

    var body: some View {
        // NOTE: NavigationStack inside HSplitView collapsed the layout to a
        // centered band and leaked the folder name as window title — removed.
        // Each pane keeps its own navigation state in its view model.
        HSplitView {
            PaneView(viewModel: left, isActive: selected == 0) { switchPane() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focused($paneFocus, equals: 0)
                .onTapGesture { selected = 0; paneFocus = 0 }
            PaneView(viewModel: right, isActive: selected == 1) { switchPane() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focused($paneFocus, equals: 1)
                .onTapGesture { selected = 1; paneFocus = 1 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear { pickStartFolderIfNeeded() }
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
