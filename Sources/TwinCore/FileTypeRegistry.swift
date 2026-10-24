import Foundation
import UniformTypeIdentifiers

/// What a file *is*, independent of which program handles it.
/// Viewers/editors in the app switch on this; it lives in TwinCore so
/// classification is unit-testable and shared (FinderSync, intents).
public enum FileKind: String, Codable, CaseIterable, Sendable {
    case text, markdown, code, image, pdf, audio, video, archive, data

    public var label: String {
        switch self {
        case .text: return "Text"
        case .markdown: return "Markdown"
        case .code: return "Code / structured text"
        case .image: return "Image"
        case .pdf: return "PDF"
        case .audio: return "Audio"
        case .video: return "Video"
        case .archive: return "Archive"
        case .data: return "Data / binary"
        }
    }

    /// Twin can edit these in the built-in text editor.
    public var isTextEditable: Bool {
        switch self {
        case .text, .markdown, .code: return true
        default: return false
        }
    }

    /// Twin has a built-in viewer for these (others fall back to
    /// Quick Look / the associated program).
    public var hasBuiltinViewer: Bool {
        switch self {
        case .text, .markdown, .code, .image, .pdf, .audio, .video, .data: return true
        case .archive: return false
        }
    }
}

/// How one extension should be handled. `systemDefault` means: do
/// what macOS would do — every other case *overrides* the system
/// default inside Twin.
public enum HandlerChoice: Codable, Equatable, Sendable {
    case twinViewer
    case twinEditor
    case externalApp(path: String, name: String)
    case customHandler(id: String)
    case systemDefault

    public var label: String {
        switch self {
        case .twinViewer: return "Twin Viewer"
        case .twinEditor: return "Twin Editor"
        case .externalApp(_, let name): return name
        case .customHandler(let id): return "Custom: \(id)"
        case .systemDefault: return "macOS default"
        }
    }
}

/// Per-extension choices. `viewer` answers F3, `editor` answers
/// F4, and `editor` (when set) also answers Enter/Open — that is
/// the override of the macOS default the guide promises.
public struct FileTypeAssociation: Codable, Equatable, Sendable {
    public var viewer: HandlerChoice?
    public var editor: HandlerChoice?
    public init(viewer: HandlerChoice? = nil, editor: HandlerChoice? = nil) {
        self.viewer = viewer
        self.editor = editor
    }
    public var isEmpty: Bool { viewer == nil && editor == nil }
}

/// A user-built handler ("my own viewer/editor"): either an app to
/// launch the file with, or a command template where `{file}` is
/// replaced by the (quoted) file path.
public struct CustomHandler: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var extensions: [String]
    public var applicationPath: String?
    public var commandTemplate: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        extensions: [String],
        applicationPath: String? = nil,
        commandTemplate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.extensions = extensions.map(FileTypeRegistry.normalizedExtension)
        self.applicationPath = applicationPath
        self.commandTemplate = commandTemplate
    }
}

public enum FileTypeRegistry {
    public static func normalizedExtension(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespaces).lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static let byExtension: [String: FileKind] = {
        var map: [String: FileKind] = [:]
        for ext in ["txt", "text", "log", "csv", "tsv"] { map[ext] = .text }
        for ext in ["md", "markdown", "mdown"] { map[ext] = .markdown }
        for ext in ["swift", "c", "h", "cc", "cpp", "cxx", "hpp", "m", "mm", "js", "ts",
                    "jsx", "tsx", "py", "rb", "go", "rs", "java", "kt", "kts", "scala",
                    "sh", "zsh", "bash", "fish", "html", "htm", "css", "scss", "json",
                    "jsonc", "yaml", "yml", "toml", "xml", "plist", "sql", "lua", "php",
                    "pl", "r", "swiftui"] {
            map[ext] = .code
        }
        for ext in ["png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "tif", "bmp",
                    "webp", "ico", "svg", "avif"] { map[ext] = .image }
        map["pdf"] = .pdf
        for ext in ["mp3", "m4a", "wav", "aiff", "aif", "flac", "ogg", "opus", "aac"] { map[ext] = .audio }
        for ext in ["mp4", "mov", "m4v", "mkv", "avi", "webm"] { map[ext] = .video }
        for ext in ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg", "pkg"] {
            map[ext] = .archive
        }
        return map
    }()

    /// Known types shown in the guide, grouped by kind.
    public static var knownExtensions: [String] {
        byExtension.keys.sorted()
    }

    public static func kind(forExtension raw: String) -> FileKind {
        let ext = normalizedExtension(raw)
        if let known = byExtension[ext] { return known }
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return .data }
        if type.conforms(to: .text) { return .text }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .archive) { return .archive }
        return .data
    }

    public static func kind(for url: URL) -> FileKind {
        kind(forExtension: url.pathExtension)
    }
}

/// Persistent store for associations + custom handlers.
/// UserDefaults-backed so it survives launches; the guide and the
/// panes read/write the same instance.
public final class FileHandlerStore: @unchecked Sendable {
    public static let shared = FileHandlerStore()

    private let defaults: UserDefaults
    private let associationsKey = "se.dvisious.twin.fileHandlers.associations.v1"
    private let customKey = "se.dvisious.twin.fileHandlers.custom.v1"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var associations: [String: FileTypeAssociation] {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let data = defaults.data(forKey: associationsKey),
                  let decoded = try? JSONDecoder().decode([String: FileTypeAssociation].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            lock.lock(); defer { lock.unlock() }
            let cleaned = newValue.filter { !$0.value.isEmpty }
            if let data = try? JSONEncoder().encode(cleaned) {
                defaults.set(data, forKey: associationsKey)
            }
        }
    }

    public var customHandlers: [CustomHandler] {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let data = defaults.data(forKey: customKey),
                  let decoded = try? JSONDecoder().decode([CustomHandler].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            lock.lock(); defer { lock.unlock() }
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: customKey)
            }
        }
    }

    public func association(forExtension raw: String) -> FileTypeAssociation {
        associations[FileTypeRegistry.normalizedExtension(raw)] ?? FileTypeAssociation()
    }

    public func association(for url: URL) -> FileTypeAssociation {
        association(forExtension: url.pathExtension)
    }

    public func setAssociation(_ association: FileTypeAssociation, forExtension raw: String) {
        var all = associations
        all[FileTypeRegistry.normalizedExtension(raw)] = association
        associations = all
    }

    @discardableResult
    public func upsertCustomHandler(_ handler: CustomHandler) -> CustomHandler {
        var all = customHandlers
        if let index = all.firstIndex(where: { $0.id == handler.id }) {
            all[index] = handler
        } else {
            all.append(handler)
        }
        customHandlers = all
        // Point every listed extension's editor at this handler.
        for ext in handler.extensions {
            var association = association(forExtension: ext)
            association.editor = .customHandler(id: handler.id)
            setAssociation(association, forExtension: ext)
        }
        return handler
    }

    public func removeCustomHandler(id: String) {
        customHandlers = customHandlers.filter { $0.id != id }
        var all = associations
        for key in Array(all.keys) {
            guard var association = all[key] else { continue }
            if association.editor == .customHandler(id: id) { association.editor = nil }
            if association.viewer == .customHandler(id: id) { association.viewer = nil }
            all[key] = association
        }
        associations = all
    }

    public func customHandler(id: String) -> CustomHandler? {
        customHandlers.first { $0.id == id }
    }

    /// Resolves a choice to what the app should actually do.
    public enum Resolved: Equatable, Sendable {
        case twinViewer(FileKind)
        case twinEditor
        case externalApp(path: String, name: String)
        case custom(CustomHandler)
        case systemDefault
    }

    /// F3 — View.
    public func viewer(for url: URL) -> Resolved {
        let kind = FileTypeRegistry.kind(for: url)
        switch association(for: url).viewer {
        case .twinViewer: return .twinViewer(kind)
        case .twinEditor: return .twinEditor
        case .externalApp(let path, let name): return .externalApp(path: path, name: name)
        case .customHandler(let id):
            if let handler = customHandler(id: id) { return .custom(handler) }
            return .twinViewer(kind)
        case .systemDefault: return .systemDefault
        case nil: return kind.hasBuiltinViewer ? .twinViewer(kind) : .systemDefault
        }
    }

    /// F4 — Edit. Also used for Enter/Open when an editor is set
    /// (the override); `open(for:)` encodes that distinction.
    public func editor(for url: URL) -> Resolved {
        let kind = FileTypeRegistry.kind(for: url)
        switch association(for: url).editor {
        case .twinEditor: return .twinEditor
        case .twinViewer: return .twinViewer(kind)
        case .externalApp(let path, let name): return .externalApp(path: path, name: name)
        case .customHandler(let id):
            if let handler = customHandler(id: id) { return .custom(handler) }
            return kind.isTextEditable ? .twinEditor : .systemDefault
        case .systemDefault: return .systemDefault
        case nil: return kind.isTextEditable ? .twinEditor : .systemDefault
        }
    }

    /// Enter / double-click: an explicit editor choice overrides
    /// macOS; without one the system default rules.
    public func open(for url: URL) -> Resolved {
        if association(for: url).editor != nil { return editor(for: url) }
        return .systemDefault
    }
}
