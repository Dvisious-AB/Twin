import Foundation
import SwiftUI

/// Tabs for one pane. Each tab is a full PaneViewModel with its own
/// folder, history, selection and search — switching tabs never loses state.
@MainActor
final class PaneTabs: ObservableObject {
    @Published var tabs: [PaneViewModel]
    @Published var activeIndex: Int = 0

    var active: PaneViewModel { tabs[activeIndex] }

    init(first: URL) {
        tabs = [PaneViewModel(initialPath: first)]
    }

    func newTab() {
        tabs.append(PaneViewModel(initialPath: active.currentURL))
        activeIndex = tabs.count - 1
    }

    func closeActive() {
        guard tabs.count > 1 else { return }
        tabs.remove(at: activeIndex)
        activeIndex = min(activeIndex, tabs.count - 1)
    }

    func close(at index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }
        tabs.remove(at: index)
        if activeIndex >= tabs.count { activeIndex = tabs.count - 1 }
    }

    func select(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
    }
}
