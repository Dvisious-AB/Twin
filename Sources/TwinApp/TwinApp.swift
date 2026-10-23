import SwiftUI
@main struct TwinApp: App {
  var body: some Scene {
    WindowGroup {
      DualPaneView().frame(minWidth: 900, minHeight: 600)
    }
  }
}
