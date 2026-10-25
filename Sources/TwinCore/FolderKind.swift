import Foundation

/// What a folder *is*, recognised from metadata instead of its
/// name alone: marker files (.git, Package.swift, package.json),
/// well-known place names (partly localised) and — when a content
/// sample is available — what most of its files are. Drives the
/// semantic folder icons in the panes; files keep their Finder
/// icons, which are already type-correct.
public enum FolderKind: String, Sendable, CaseIterable {
    case generic
    case git
    case swiftPackage
    case xcodeProject
    case node
    case rust
    case go
    case docker
    case code
    case samples
    case music
    case pictures
    case movies
    case downloads
    case documents
    case desktop
    case applications
}

public enum FolderKindClassifier {
    /// Name rules (English + Swedish place names Twin's users have).
    private static let nameRules: [(FolderKind, [String])] = [
        (.samples, ["samples", "sample library", "samplepack", "sample pack", "splice"]),
        (.music, ["music", "musik", "itunes media"]),
        (.pictures, ["pictures", "bilder", "photos", "foton", "dcim"]),
        (.movies, ["movies", "filmer", "video", "videos", "tv"]),
        (.downloads, ["downloads", "hämtningar", "nedladdningar"]),
        (.documents, ["documents", "dokument"]),
        (.desktop, ["desktop", "skrivbord"]),
        (.applications, ["applications", "program"])
    ]

    /// Pure classification from a folder name + its top-level entry
    /// names. Cheap to test; the app feeds real listings in.
    public static func classify(folderName: String, contents: [String]) -> FolderKind {
        let loweredName = folderName.lowercased()
        for (kind, needles) in nameRules where needles.contains(loweredName) {
            return kind
        }

        let entries = Set(contents.map { $0.lowercased() })
        // Project markers beat content majorities: a repo full of
        // images is still a repo.
        if entries.contains(".git") || entries.contains(".hg") { return .git }
        if contents.contains(where: { $0.lowercased().hasSuffix(".xcodeproj") }) { return .xcodeProject }
        if entries.contains("package.swift") { return .swiftPackage }
        if entries.contains("package.json") { return .node }
        if entries.contains("cargo.toml") { return .rust }
        if entries.contains("go.mod") { return .go }
        if entries.contains("dockerfile") || entries.contains("docker-compose.yml") { return .docker }

        // Majority rules from extensions (needs a meaningful sample).
        guard contents.count >= 3 else { return .generic }
        var audio = 0, image = 0, video = 0, code = 0
        for entry in contents {
            switch FileTypeRegistry.kind(forExtension: (entry as NSString).pathExtension) {
            case .audio: audio += 1
            case .image: image += 1
            case .video: video += 1
            case .code, .text, .markdown: code += 1
            default: break
            }
        }
        let total = contents.count
        if audio * 2 > total {
            return loweredName.contains("sample") ? .samples : .music
        }
        if image * 2 > total { return .pictures }
        if video * 2 > total { return .movies }
        if code * 2 > total { return .code }
        return .generic
    }

    /// Classifies a real folder: name rules first (free), then a
    /// shallow listing for markers/majorities. Protected TCC
    /// folders are never listed — they classify by name only.
    public static func classify(url: URL) -> FolderKind {
        let name = url.lastPathComponent
        let byName = classify(folderName: name, contents: [])
        if byName != .generic { return byName }
        if DirectorySizeService.isProtectedFolder(url) { return .generic }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return classify(folderName: name, contents: contents)
    }
}
