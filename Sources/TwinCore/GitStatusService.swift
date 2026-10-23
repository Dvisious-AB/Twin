import Foundation

/// Git badges (Pro): per-file status from `git status --porcelain`.
/// Read-only — Twin never runs mutating git commands.
public enum GitStatusService {

    public enum Badge: String, Sendable, Equatable {
        case modified = "M"
        case added = "A"
        case untracked = "?"
        case deleted = "D"
        case renamed = "R"
        case ignored = "!"
        case clean = ""

        public var isDirty: Bool { self != .clean && self != .ignored }
    }

    /// Repo root for a directory, or nil when not inside a work tree.
    public static func repositoryRoot(for directory: URL) -> URL? {
        runGit(["rev-parse", "--show-toplevel"], in: directory)
            .map { URL(fileURLWithPath: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// Maps absolute file path -> badge for every dirty file under `directory`'s repo.
    public static func badges(for directory: URL) -> [String: Badge] {
        guard let root = repositoryRoot(for: directory),
              let output = runGit(["status", "--porcelain", "--ignored=matching"], in: directory) else {
            return [:]
        }
        var result: [String: Badge] = [:]
        for line in output.split(separator: "\n") {
            guard line.count >= 4 else { continue }
            let xy = line.prefix(2)
            let rawPath = String(line.dropFirst(3))
            // Renames come as "old -> new"; the badge belongs to the new path.
            let path = rawPath.components(separatedBy: " -> ").last ?? rawPath
            // Canonicalise so keys match file URLs from directory listings
            // even when /var vs /private/var symlinks are involved.
            let absolute = root.appendingPathComponent(path).resolvingSymlinksInPath().path
            result[absolute] = badge(for: xy)
        }
        return result
    }

    static func badge(for xy: Substring) -> Badge {
        if xy == "??" { return .untracked }
        if xy == "!!" { return .ignored }
        let chars = Set(xy)
        if chars.contains("D") { return .deleted }
        if chars.contains("R") { return .renamed }
        if chars.contains("A") { return .added }
        if chars.contains("M") { return .modified }
        return .clean
    }

    private static func runGit(_ arguments: [String], in directory: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
