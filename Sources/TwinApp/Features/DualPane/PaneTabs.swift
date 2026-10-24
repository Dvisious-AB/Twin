import Combine
import Foundation
import SwiftUI

/// Tabs for one pane. Each tab is a full PaneViewModel with its own
/// folder, history, selection and search — switching tabs never loses state.
@MainActor
final class PaneTabs: ObservableObject {
    @Published var tabs: [PaneViewModel]
    @Published var activeIndex: Int = 0
    private var childObservers: [AnyCancellable] = []
    private var urlObservers: [AnyCancellable] = []
    private let storageKey: String?

    /// Tab labels show the folder name, so forward child view-model
    /// changes (navigation) to our own observers.
    private func observeChildren() {
        childObservers = tabs.map { tab in
            tab.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        }
        // Persist the session on every navigation so the next launch
        // resumes in the user's real folders — never back in the
        // sandbox container once folders have been chosen.
        urlObservers = tabs.map { tab in
            tab.$currentURL.sink { [weak self] _ in self?.persist() }
        }
    }

    private func persist() {
        guard let storageKey else { return }
        UserDefaults.standard.set(tabs.map { $0.currentURL.path }, forKey: storageKey + ".paths")
        UserDefaults.standard.set(activeIndex, forKey: storageKey + ".active")
    }

    var active: PaneViewModel { tabs[activeIndex] }

    init(first: URL, storageKey: String? = nil) {
        self.storageKey = storageKey
        if let storageKey,
           let paths = UserDefaults.standard.stringArray(forKey: storageKey + ".paths"),
           !paths.isEmpty {
            tabs = paths.map { PaneViewModel(initialPath: URL(fileURLWithPath: $0)) }
            activeIndex = min(max(UserDefaults.standard.integer(forKey: storageKey + ".active"), 0), tabs.count - 1)
        } else {
            tabs = [PaneViewModel(initialPath: first)]
        }
        observeChildren()
    }

    func newTab() {
        tabs.append(PaneViewModel(initialPath: active.currentURL))
        activeIndex = tabs.count - 1
        observeChildren()
        persist()
    }

    func closeActive() {
        guard tabs.count > 1 else { return }
        tabs.remove(at: activeIndex)
        activeIndex = min(activeIndex, tabs.count - 1)
        observeChildren()
        persist()
    }

    func close(at index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }
        tabs.remove(at: index)
        if activeIndex >= tabs.count { activeIndex = tabs.count - 1 }
        observeChildren()
        persist()
    }

    /// Rebuilds tabs from saved paths (workspace restore).
    func restore(paths: [String], active: Int) {
        guard !paths.isEmpty else { return }
        tabs = paths.map { PaneViewModel(initialPath: URL(fileURLWithPath: $0)) }
        activeIndex = min(max(active, 0), tabs.count - 1)
        observeChildren()
        persist()
    }

    func select(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
        persist()
    }
}
