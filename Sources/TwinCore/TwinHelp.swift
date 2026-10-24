import Foundation

/// Twin's built-in help knowledge: the manual the assistant answers from.
/// Used both as instructions for the on-device language model and as the
/// rule-based fallback when no model is available. Pure and testable.
public enum TwinHelp {

    /// Compact manual injected as LLM instructions/context.
    public static let manual = """
    Twin is a dual-pane file manager for Mac (beginner to advanced).
    Layout: two independent panes, each with its own tabs (Cmd+T new, Cmd+W close), \
    folder history (Alt+Left/Right), breadcrumbs and filter field (Cmd+F).
    Navigation: arrow keys move, Enter opens, Backspace (Delete key) goes up one level, \
    Tab or Cmd+1/Cmd+2 switches pane, Cmd+Option+R goes to root, Space opens Quick Look. \
    When you go up, the cursor lands on the folder you came from.
    Copy/move: F5 (Cmd+5) copies the selection to the other pane, F6 (Cmd+6) moves. \
    Drag between panes copies; hold Option while dropping to move. Existing files are \
    never overwritten silently — they are skipped and reported in the status bar.
    Sorting: directories first, then files; click Name/Size/Modified to sort. Folder \
    sizes are calculated in the background and cached.
    File actions (bottom bar): Edit (Cmd+E, built-in editor, Cmd+S saves), Pack zip \
    (Cmd+Shift+C), MD5 checksum file (Cmd+Shift+M), Encrypt/decrypt AES-GCM .twinenc \
    (Cmd+Shift+E), New Folder (Cmd+7), Rename (Cmd+Shift+R), Unpack zip (Cmd+Shift+U), \
    Permissions (Cmd+I), Delete to Trash (Cmd+Delete, always confirmed, never hard delete).
    Permissions: Owner/Group/Everyone read-write-open ticks, presets like Private (700) \
    or Shared in group (770); octal and symbolic form shown for advanced users.
    Search: filter field per pane filters instantly; Esc clears.
    Sandbox note: a banner saying "Sandbox container — not your files" means the pane \
    shows Twin's own container; use Choose Folder to pick a real folder (bookmarked).
    Pro (Twin Pro, one-time): Workspaces (save/restore all tabs), Folder Sync between \
    panes (extras only deleted in explicit mirror mode, to Trash), Batch Rename with \
    preview (find/replace, prefix/suffix, numbering), Git badges M/? in the Name column \
    (read-only git status). Locked Pro actions open the paywall.
    Assistant: the Assistant button can sort loose files into Images, Documents, \
    Archives, Audio, Video, Code and Other folders — moved, never copied, folders untouched.
    Privacy: everything, including the assistant, runs on-device.
    """

    public struct HelpTopic: Sendable {
        public let keywords: [String]
        public let answer: String
    }

    public static let topics: [HelpTopic] = [
        HelpTopic(keywords: ["sort", "organis", "organiz", "städa", "kategor"],
                  answer: "Use Assistant → Sort Into Folders: loose files are grouped into Images, Documents, Archives, Audio," +
                      "Video, Code and Other. " +
                          "Directories are never moved, and files are moved — not copied. To sort the list itself, click the Name," +
                              "Size or Modified header; folders always come first."),
        HelpTopic(keywords: ["encrypt", "krypter", "lösen", "password", "aes"],
                  answer: "Select a file and press Cmd+Shift+E (Encrypt in the bottom bar). You get an AES-GCM encrypted .twinenc" +
                      "file protected by your passphrase. " +
                          "Run the same command on a .twinenc file to decrypt it. Twin can't recover a lost passphrase."),
        HelpTopic(keywords: ["permission", "behörig", "chmod", "säkerhet", "rättighet", "skydda"],
                  answer: "Select one file or folder and press Cmd+I (Permissions). Tick who may read, write and open/run — Owner," +
                      "Group, Everyone — " +
                          "or pick a preset like Private (700). Advanced users see the symbolic form (rwxr-xr-x) and octal value in" +
                              "the same view."),
        HelpTopic(keywords: ["copy", "kopier", "flytta", "move", "andra panel"],
                  answer: "Mark files with the arrow keys, then F5 (Cmd+5) copies to the other pane and F6 (Cmd+6) moves. " +
                          "Dragging between panes copies; hold Option while dropping to move. Existing files are skipped and" +
                              "reported, never overwritten silently."),
        HelpTopic(keywords: ["tab", "flik"],
                  answer: "Each pane has its own tabs: Cmd+T opens a new tab in the active pane, Cmd+W closes it, and the × on a" +
                      "tab closes that one. Every tab keeps its own folder, history, selection and filter."),
        HelpTopic(keywords: ["workspace", "arbetsyta", "spara panel"],
                  answer: "Workspaces (Pro) saves both panes with all their tabs under a name: Workspaces menu → Save Current." +
                      "Restore from the same menu. Locked? The paywall opens instead — Workspaces is a Twin Pro feature."),
        HelpTopic(keywords: ["sync", "synk", "spegel", "mirror"],
                  answer: "Folder Sync (Pro): Sync button in the bottom bar compares the active pane with the other pane" +
                      "recursively and shows the plan first (only here / only in target / different / same). " +
                          "Sync copies missing and changed files. Extras in the target are only removed in explicit mirror mode," +
                              "and then to the Trash."),
        HelpTopic(keywords: ["rename", "döp", "batch"],
                  answer: "Rename one item with Cmd+Shift+R. For many at once (Pro): Batch Rename in the bottom bar with" +
                      "find/replace, prefix/suffix and optional numbering — the preview shows old → new for every file before" +
                      "anything changes."),
        HelpTopic(keywords: ["md5", "checksum", "hash"],
                  answer: "Select files and press Cmd+Shift+M (MD5). Twin writes a .md5 file next to each original with its" +
                      "checksum, e.g. for verifying copies."),
        HelpTopic(keywords: ["zip", "compress", "komprimer", "pack", "arkiv", "archive", "unpack", "packa upp"],
                  answer: "Pack: select files and press Cmd+Shift+C to create a .zip next to them. Unpack: select a .zip and press" +
                      "Cmd+Shift+U — it expands into a folder with the archive's name."),
        HelpTopic(keywords: ["delete", "radera", "trash", "papperskorg", "ta bort"],
                  answer: "Cmd+Delete moves the selection to the Trash after a confirmation. Twin never hard-deletes, so you can" +
                      "always undo from Finder's Trash."),
        HelpTopic(keywords: ["edit", "rediger", "text", "editor", "anteckn"],
                  answer: "Select a text file and press Cmd+E to open Twin's built-in editor. Cmd+S saves back to the same file." +
                      "Files over 2 MB or non-UTF-8 files can't be edited this way."),
        HelpTopic(keywords: ["view", "visa", "viewer", "f3", "förhandsvisa", "öppna med", "open with",
                              "filtyp", "file type", "standardapp", "default app", "extern editor", "egen editor"],
                  answer: "F3 opens Twin's built-in viewer (text/code with line numbers, Markdown rendered, images, PDF, " +
                      "media, hex for binary files). To connect a file type to another viewer or editor: right-click a file " +
                      "▸ Open With ▸ Koppla filtyp… (guide), or Files ▸ File Type Handlers…. There you pick per extension " +
                      "what F3 shows and what F4/Enter opens — Twin Viewer/Editor, an external app, your own handler " +
                      "(an app or a command like /usr/local/bin/tool {file}), or the macOS default. Setting an editor " +
                      "overrides the macOS default inside Twin."),
        HelpTopic(keywords: ["size", "storlek", "mappstorlek", "utrymme", "disk"],
                  answer: "Folder sizes are calculated automatically in the background and cached — watch the Size column fill in" +
                      "(… means still counting), then click Size to sort by it. The status bar shows free space on the volume."),
        HelpTopic(keywords: ["git", "badge", "märke", "modified", "repo"],
                  answer: "Git badges (Pro) show M for modified and ? for untracked files in the Name column, straight from git" +
                      "status. Twin only reads git — it never commits or changes your repo."),
        HelpTopic(keywords: ["container", "sandbox", "sandlåda", "inte mina filer", "choose folder", "startmapp", "hemmamapp"],
                  answer: "The orange banner means the pane shows Twin's sandbox container, not your real files. Click Choose" +
                      "Folder in the banner and pick your folder (for example your home folder) — Twin bookmarks it and remembers" +
                      "it per pane."),
        HelpTopic(keywords: ["navigate", "navigera", "tangent", "keyboard", "genväg", "shortcut", "upp en nivå",
                             "backspace", "delete"],
                  answer: "Arrows move, Enter opens, Backspace (the Delete key) goes up one level, Alt+Left/Right walks folder" +
                      "history, Tab switches pane, Cmd+F jumps to the filter, Space is Quick Look. The full map is in" +
                      "Docs/TC-Research.md."),
        HelpTopic(keywords: ["pro", "köpa", "pris", "betala", "låst", "unlock"],
                  answer: "Twin Lite is free. Twin Pro (one-time purchase) adds Workspaces, Folder Sync, Batch Rename and Git" +
                      "badges. Locked actions open the paywall where you can buy or restore — Restore Purchases brings back an" +
                      "earlier buy."),
        HelpTopic(keywords: ["siri", "shortcut", "genvägar-app", "automation"],
                  answer: "Twin exposes Siri/Shortcuts actions: ask Siri to organize a folder or create an MD5 with Twin, or find" +
                      "Twin in the Shortcuts app. The actions run Twin's own services on the folder or file you give them.")
    ]

    public static let fallbackAnswer =
        "I answer questions about using Twin: navigation, copying (Cmd+5/6), sorting, folder sizes, permissions (Cmd+I), " +
        "encrypting (Cmd+Shift+E), zip (Cmd+Shift+C/U), MD5 (Cmd+Shift+M), editing (Cmd+E), tabs (Cmd+T), Workspaces, Folder Sync, " +
        "Batch Rename and Git badges. Try asking about any of those."

    /// Rule-based answer used when no on-device model is available.
    public static func answer(to question: String) -> String {
        let query = question.lowercased()
        var best: (score: Int, answer: String)?
        for topic in topics {
            let score = topic.keywords.filter { query.contains($0) }.count
            if score > 0, score > (best?.score ?? 0) {
                best = (score, topic.answer)
            }
        }
        return best?.answer ?? fallbackAnswer
    }

    /// Suggested starter questions for the chat UI.
    public static let suggestions = [
        "How do I copy files to the other pane?",
        "How do I protect a folder so only I can read it?",
        "How do I sort this messy folder?",
        "How do I encrypt a file?",
        "What do the M and ? badges mean?",
        "How do tabs work?"
    ]
}
