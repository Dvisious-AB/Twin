import SwiftUI

struct DualPaneView: View {
    @StateObject var left = PaneViewModel(initialPath: FileManager.default.homeDirectoryForCurrentUser)
    @StateObject var right = PaneViewModel(
        initialPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    )
    @State var selected: Int = 0
    @FocusState private var paneFocus: Int?

    private func switchPane() {
        selected = selected == 0 ? 1 : 0
        paneFocus = selected
    }

    private var activePane: PaneViewModel { selected == 0 ? left : right }
    private var inactivePane: PaneViewModel { selected == 0 ? right : left }

    var body: some View {
        HSplitView {
            // Two independent NavigationStacks — one per pane (LeadUX).
            NavigationStack(path: $left.navigationPath) {
                PaneView(viewModel: left, isActive: selected == 0) { switchPane() }
                    .navigationTitle(left.currentURL.lastPathComponent)
                    .focused($paneFocus, equals: 0)
                    .onTapGesture { selected = 0; paneFocus = 0 }
            }
            NavigationStack(path: $right.navigationPath) {
                PaneView(viewModel: right, isActive: selected == 1) { switchPane() }
                    .navigationTitle(right.currentURL.lastPathComponent)
                    .focused($paneFocus, equals: 1)
                    .onTapGesture { selected = 1; paneFocus = 1 }
            }
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
                Button("Left") { selected = 0; paneFocus = 0 }
                    .keyboardShortcut("1", modifiers: .command)
                    .help("Activate left pane (Cmd+1)")
                Button("Right") { selected = 1; paneFocus = 1 }
                    .keyboardShortcut("2", modifiers: .command)
                    .help("Activate right pane (Cmd+2)")
                Button("F5 Copy") {
                    Task { await activePane.copySelected(to: inactivePane.currentURL); inactivePane.refresh() }
                }
                .keyboardShortcut("5", modifiers: .command)
                .help("Copy selected to other pane (F5 / Cmd+5)")

                Button("F6 Move") {
                    Task { await activePane.moveSelected(to: inactivePane.currentURL); inactivePane.refresh() }
                }
                .keyboardShortcut("6", modifiers: .command)
                .help("Move selected to other pane (F6 / Cmd+6)")
            }
        }
    }
}
