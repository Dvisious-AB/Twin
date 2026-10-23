import SwiftUI
struct DualPaneView: View {
  @StateObject var left = PaneViewModel(initialPath: FileManager.default.homeDirectoryForCurrentUser)
  @StateObject var right = PaneViewModel(initialPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"))
  @State var selected: Int = 0
  var body: some View {
    HSplitView {
      PaneView(viewModel: left, isActive: selected==0).onTapGesture{selected=0}
      PaneView(viewModel: right, isActive: selected==1).onTapGesture{selected=1}
    }.toolbar{
      ToolbarItem{ Button("F5 Copy"){ Task{ await left.copySelected(to: right.currentURL)} }.keyboardShortcut(.f5, modifiers: []) }
      ToolbarItem{ Button("F6 Move"){ Task{ await left.moveSelected(to: right.currentURL)} }.keyboardShortcut(.f6, modifiers: []) }
    }
  }
}
