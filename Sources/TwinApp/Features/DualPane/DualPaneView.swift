import SwiftUI

struct DualPaneView: View {
    @StateObject var left = PaneViewModel(initialPath: FileManager.default.homeDirectoryForCurrentUser)
    @StateObject var right = PaneViewModel(
        initialPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    )
    @State var selected: Int = 0

    private var activePane: PaneViewModel { selected == 0 ? left : right }
    private var inactivePane: PaneViewModel { selected == 0 ? right : left }

    var body: some View {
        HSplitView {
            PaneView(viewModel: left, isActive: selected == 0)
                .onTapGesture { selected = 0 }
            PaneView(viewModel: right, isActive: selected == 1)
                .onTapGesture { selected = 1 }
        }
        .toolbar {
            ToolbarItemGroup {
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
