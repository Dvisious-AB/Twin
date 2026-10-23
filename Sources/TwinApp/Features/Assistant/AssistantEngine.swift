import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Answers help questions. Prefers Apple's on-device model when the
/// system offers it; otherwise (and on any error) a rule-based fallback
/// covering Twin's core tasks. Always local.
enum AssistantEngine {

    static var statusText: String {
        if isModelAvailable {
            return "On-device model (Apple Foundation Models) — private, offline."
        }
        return "Built-in help (on-device model not available on this Mac)."
    }

    static var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func answer(to question: String, folder: URL) async -> String {
        if let modelAnswer = await modelAnswer(to: question, folder: folder) {
            return modelAnswer
        }
        return ruleBasedAnswer(to: question)
    }

    private static func modelAnswer(to question: String, folder: URL) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isModelAvailable {
            do {
                let session = LanguageModelSession(
                    instructions: "You are Twin's help assistant inside a dual-pane file manager for Mac. Answer briefly and" +
                        "concretely, referring to Twin's shortcuts: arrows navigate, Enter opens, Backspace goes up, Tab switches" +
                        "pane, Cmd+F filters, F5/Cmd+5 copy, F6/Cmd+6 move, Cmd+E edit, Cmd+Shift+C pack zip, Cmd+Shift+M MD5," +
                        "Cmd+Shift+E encrypt, Cmd+Delete trash, Cmd+I permissions."
                )
                let response = try await session.respond(
                    to: "The user is in folder \(folder.lastPathComponent). Question: \(question)"
                )
                return response.content
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    static func ruleBasedAnswer(to question: String) -> String {
        let q = question.lowercased()
        if q.contains("sort") || q.contains("organis") || q.contains("organiz") || q.contains("städa") {
            return "Use Sort Into Folders above: files are grouped into Images, Documents, Archives, Audio, Video, Code and Other." +
                "Directories are never moved, and files are moved — not copied."
        }
        if q.contains("encrypt") || q.contains("krypter") || q.contains("password") || q.contains("lösen") {
            return "Select a file and press Cmd+Shift+E (or Encrypt in the bottom bar). You get an AES-GCM encrypted .twinenc file" +
                "protected by your passphrase. Run the same command on a .twinenc file to decrypt it."
        }
        if q.contains("permission") || q.contains("behörig") || q.contains("chmod") || q.contains("säkerhet") {
            return "Select a file or folder and press Cmd+I (Permissions in the bottom bar). Tick who may read, write and open/run —" +
                "or pick a preset like Private. The octal value is shown for advanced users."
        }
        if q.contains("copy") || q.contains("kopier") {
            return "Mark files with the arrow keys, then F5 (Cmd+5) copies to the other pane and F6 (Cmd+6) moves. You can also drag" +
                "between panes. Existing files are never overwritten silently — they are skipped and reported."
        }
        if q.contains("md5") || q.contains("checksum") {
            return "Select files and press Cmd+Shift+M. Twin writes a .md5 file next to each one with its checksum."
        }
        if q.contains("zip") || q.contains("compress") || q.contains("komprimer") || q.contains("pack") {
            return "Select files and press Cmd+Shift+C (Pack) to create a .zip next to them."
        }
        if q.contains("delete") || q.contains("radera") || q.contains("trash") {
            return "Cmd+Delete moves the selection to the Trash after a confirmation. Twin never hard-deletes."
        }
        if q.contains("edit") || q.contains("rediger") || q.contains("text") {
            return "Select a text file and press Cmd+E to open Twin's built-in editor. Cmd+S saves back to the same file."
        }
        if q.contains("size") || q.contains("storlek") || q.contains("mappstorlek") {
            return "Folder sizes are calculated automatically in the background and cached — just look at the Size column, then click" +
                "Size to sort by it."
        }
        return "I can help with: sorting a folder, permissions (Cmd+I), encrypting (Cmd+Shift+E), packing zip (Cmd+Shift+C), MD5" +
            "(Cmd+Shift+M), copying (Cmd+5) and editing (Cmd+E). Ask about any of them."
    }
}
