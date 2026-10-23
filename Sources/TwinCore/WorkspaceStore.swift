import Foundation

/// A saved workspace: both panes' tabs and which side/tab was active.
/// Pro feature — the UI gates it, storage is plain Codable here.
public struct Workspace: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var leftTabs: [String]
    public var rightTabs: [String]
    public var activeLeftTab: Int
    public var activeRightTab: Int
    public var activeSide: Int

    public init(
        id: UUID = UUID(), name: String,
        leftTabs: [String], rightTabs: [String],
        activeLeftTab: Int = 0, activeRightTab: Int = 0, activeSide: Int = 0
    ) {
        self.id = id
        self.name = name
        self.leftTabs = leftTabs
        self.rightTabs = rightTabs
        self.activeLeftTab = activeLeftTab
        self.activeRightTab = activeRightTab
        self.activeSide = activeSide
    }
}

/// Persists workspaces as JSON in UserDefaults.
public final class WorkspaceStore: @unchecked Sendable {
    public static let shared = WorkspaceStore()
    public static let defaultsKey = "se.dvisious.twin.workspaces.v1"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = WorkspaceStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [Workspace] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Workspace].self, from: data) else { return [] }
        return decoded
    }

    public func save(_ workspace: Workspace) {
        var all = load()
        all.removeAll { $0.id == workspace.id || $0.name == workspace.name }
        all.append(workspace)
        persist(all)
    }

    public func delete(id: UUID) {
        persist(load().filter { $0.id != id })
    }

    private func persist(_ workspaces: [Workspace]) {
        if let data = try? JSONEncoder().encode(workspaces) {
            defaults.set(data, forKey: key)
        }
    }
}
