import AppKit
import Foundation
import TwinCore
import UniformTypeIdentifiers

/// Launches files with resolved handlers: external apps and
/// user-built custom handlers. Built-in viewer/editor and the
/// macOS default are handled by the caller / NSWorkspace.
enum FileLauncher {
    /// Apps macOS says can open this file (for Open With + guide).
    static func applications(for url: URL) -> [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: url)
    }

    static func applications(forExtension ext: String) -> [URL] {
        guard let type = UTType(filenameExtension: FileTypeRegistry.normalizedExtension(ext))
        else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: type)
    }

    static func appName(for appURL: URL) -> String {
        appURL.deletingPathExtension().lastPathComponent
    }

    /// Opens `url` with the app at `appPath` (.app bundle or binary).
    @discardableResult
    static func open(_ url: URL, withAppAt appPath: String) -> String? {
        let appURL = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appPath) else {
            return "\(appName(for: appURL)) is not installed at \(appPath)."
        }
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        return nil
    }

    /// Runs a user-built handler: app path wins, otherwise the
    /// command template with `{file}` replaced by the quoted path.
    @discardableResult
    static func run(custom handler: CustomHandler, for url: URL) -> String? {
        if let appPath = handler.applicationPath, !appPath.isEmpty {
            return open(url, withAppAt: appPath)
        }
        guard let template = handler.commandTemplate, !template.isEmpty else {
            return "Custom handler \(handler.name) has neither an app nor a command."
        }
        let quoted = "'" + url.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = template.replacingOccurrences(of: "{file}", with: quoted)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        do {
            try process.run()
            return nil
        } catch {
            return "Could not run \(handler.name): \(error.localizedDescription)"
        }
    }

    static func launch(_ resolved: FileHandlerStore.Resolved, for url: URL) -> String? {
        switch resolved {
        case .externalApp(let path, _): return open(url, withAppAt: path)
        case .custom(let handler): return run(custom: handler, for: url)
        case .systemDefault: NSWorkspace.shared.open(url); return nil
        case .twinViewer, .twinEditor: return nil // caller opens the sheet
        }
    }

    /// Best-effort: ask Launch Services to make Twin the macOS
    /// default for this extension. Sandboxed builds may be refused;
    /// the caller shows the outcome instead of promising success.
    static func trySetTwinAsMacDefault(forExtension ext: String) -> String {
        guard let type = UTType(filenameExtension: FileTypeRegistry.normalizedExtension(ext)),
              let bundleID = Bundle.main.bundleIdentifier else {
            return "Unknown file type — can't set a macOS default."
        }
        let status = LSSetDefaultRoleHandlerForContentType(
            type.identifier as CFString, .all, bundleID as CFString)
        return status == noErr
            ? "macOS default for .\(ext) is now Twin (best effort — verify in Finder ▸ Get Info)."
            : "macOS refused (code \(status)). The Twin-internal override above still applies."
    }
}
