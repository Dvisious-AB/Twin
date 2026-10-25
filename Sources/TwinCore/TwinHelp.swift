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
        /// Hand-written Swedish version (nil = English fallback).
        public var answerSV: String?

        public init(keywords: [String], answer: String, answerSV: String? = nil) {
            self.keywords = keywords
            self.answer = answer
            self.answerSV = answerSV
        }

        public func localized(code: String) -> String {
            code == "sv" ? (answerSV ?? answer) : answer
        }
    }

    public static let topics: [HelpTopic] = [
        HelpTopic(keywords: ["sort", "organis", "organiz", "städa", "kategor"],
                  answer: "Use Assistant → Sort Into Folders: loose files are grouped into Images, Documents, Archives, Audio," +
                      "Video, Code and Other. " +
                          "Directories are never moved, and files are moved — not copied. To sort the list itself, click the Name," +
                              "Size or Modified header; folders always come first.",
                  answerSV: "Använd Assistent → Sort Into Folders: lösa filer grupperas i Images, Documents, Archives, Audio, Video, Code och Other. Kataloger flyttas aldrig, och filer flyttas — kopieras inte. Klicka på Name, Size eller Modified för att sortera listan; mappar kommer alltid först."),
        HelpTopic(keywords: ["encrypt", "krypter", "lösen", "password", "aes"],
                  answer: "Select a file and press Cmd+Shift+E (Encrypt in the bottom bar). You get an AES-GCM encrypted .twinenc" +
                      "file protected by your passphrase. " +
                          "Run the same command on a .twinenc file to decrypt it. Twin can't recover a lost passphrase.",
                  answerSV: "Markera en fil och tryck Cmd+Shift+E (Encrypt i bottenraden). Du får en AES-GCM-krypterad .twinenc-fil skyddad av din lösenfras. Kör samma kommando på en .twinenc-fil för att dekryptera. Twin kan inte återställa en borttappad lösenfras."),
        HelpTopic(keywords: ["permission", "behörig", "chmod", "säkerhet", "rättighet", "skydda"],
                  answer: "Select one file or folder and press Cmd+I (Permissions). Tick who may read, write and open/run — Owner," +
                      "Group, Everyone — " +
                          "or pick a preset like Private (700). Advanced users see the symbolic form (rwxr-xr-x) and octal value in" +
                              "the same view.",
                  answerSV: "Markera en fil eller mapp och tryck Cmd+I (Permissions). Bocka i vem som får läsa, skriva och öppna/köra — Owner, Group, Everyone — eller välj en förinställning som Private (700). Avancerade ser symbolformen (rwxr-xr-x) och oktalvärdet i samma vy."),
        HelpTopic(keywords: ["copy", "kopier", "flytta", "move", "andra panel"],
                  answer: "Mark files with the arrow keys, then F5 (Cmd+5) copies to the other pane and F6 (Cmd+6) moves. " +
                          "Dragging between panes copies; hold Option while dropping to move. Existing files are skipped and" +
                              "reported, never overwritten silently.",
                  answerSV: "Markera filer med piltangenterna. F5 (Cmd+5) kopierar till andra panelen, F6 (Cmd+6) flyttar. Drag mellan paneler kopierar; håll Option vid släpp för att flytta. Befintliga filer hoppas över och rapporteras — de skrivs aldrig över i tysthet."),
        HelpTopic(keywords: ["tab", "flik"],
                  answer: "Each pane has its own tabs: Cmd+T opens a new tab in the active pane, Cmd+W closes it, and the × on a" +
                      "tab closes that one. Every tab keeps its own folder, history, selection and filter.",
                  answerSV: "Varje panel har egna flikar: Cmd+T öppnar en ny flik i den aktiva panelen, Cmd+W stänger den, och × på en flik stänger just den. Varje flik behåller sin mapp, historik, markering och sitt filter."),
        HelpTopic(keywords: ["workspace", "arbetsyta", "spara panel"],
                  answer: "Workspaces (Pro) saves both panes with all their tabs under a name: Workspaces menu → Save Current." +
                      "Restore from the same menu. Locked? The paywall opens instead — Workspaces is a Twin Pro feature.",
                  answerSV: "Workspaces (Pro) sparar båda panelerna med alla flikar under ett namn: Workspaces-menyn → Save Current. Återställ från samma meny. Låst? Då öppnas paywallen i stället — Workspaces är en Pro-funktion."),
        HelpTopic(keywords: ["sync", "synk", "spegel", "mirror"],
                  answer: "Folder Sync (Pro): Sync button in the bottom bar compares the active pane with the other pane" +
                      "recursively and shows the plan first (only here / only in target / different / same). " +
                          "Sync copies missing and changed files. Extras in the target are only removed in explicit mirror mode," +
                              "and then to the Trash.",
                  answerSV: "Folder Sync (Pro): Sync-knappen i bottenraden jämför den aktiva panelen med den andra rekursivt och visar planen först (bara här / bara i mål / ändrad / samma). Sync kopierar saknade och ändrade filer. Extra filer i målet tas bara bort i uttryckligt spegelläge, och då till papperskorgen."),
        HelpTopic(keywords: ["rename", "döp", "batch"],
                  answer: "Rename one item with Cmd+Shift+R. For many at once (Pro): Batch Rename in the bottom bar with" +
                      "find/replace, prefix/suffix and optional numbering — the preview shows old → new for every file before" +
                      "anything changes.",
                  answerSV: "Döp om en fil med Cmd+Shift+R. För många på en gång (Pro): Batch Rename i bottenraden med sök/ersätt, prefix/suffix och valfri numrering — förhandsvisningen visar gammalt → nytt för varje fil innan något ändras."),
        HelpTopic(keywords: ["md5", "checksum", "hash"],
                  answer: "Select files and press Cmd+Shift+M (MD5). Twin writes a .md5 file next to each original with its" +
                      "checksum, e.g. for verifying copies.",
                  answerSV: "Markera filer och tryck Cmd+Shift+M (MD5). Twin skriver en .md5-fil bredvid varje original med dess kontrollsumma, till exempel för att verifiera kopior."),
        HelpTopic(keywords: ["zip", "compress", "komprimer", "pack", "arkiv", "archive", "unpack", "packa upp"],
                  answer: "Pack: select files and press Cmd+Shift+C to create a .zip next to them. Unpack: select a .zip and press" +
                      "Cmd+Shift+U — it expands into a folder with the archive's name.",
                  answerSV: "Packa: markera filer och tryck Cmd+Shift+C för att skapa en .zip bredvid dem. Packa upp: markera en .zip och tryck Cmd+Shift+U — den expanderas till en mapp med arkivets namn."),
        HelpTopic(keywords: ["delete", "radera", "trash", "papperskorg", "ta bort"],
                  answer: "Cmd+Delete moves the selection to the Trash after a confirmation. Twin never hard-deletes, so you can" +
                      "always undo from Finder's Trash.",
                  answerSV: "Cmd+Delete flyttar markeringen till papperskorgen efter en bekräftelse. Twin hård-raderar aldrig, så du kan alltid ångra från Finders papperskorg."),
        HelpTopic(keywords: ["edit", "rediger", "text", "editor", "anteckn"],
                  answer: "Select a text file and press Cmd+E to open Twin's built-in editor. Cmd+S saves back to the same file." +
                      "Files over 2 MB or non-UTF-8 files can't be edited this way.",
                  answerSV: "Markera en textfil och tryck Cmd+E för att öppna Twins inbyggda editor. Cmd+S sparar tillbaka till samma fil. Filer över 2 MB eller som inte är UTF-8 går inte att redigera så här."),
        HelpTopic(keywords: ["apple intelligence", "siri", "llm", "on-device", "modell", "model",
                              "språk", "language", "kom igång", "setup", "installera ai", "aktivera"],
                  answer: "Twin uses Apple's on-device model when it's available. Set it up: 1) Open System Settings ▸ " +
                      "Apple Intelligence & Siri (just Siri in newer macOS) and turn it on / join Siri AI. 2) The model " +
                      "downloads automatically (several GB, keep Wi-Fi and power connected). 3) Language rule: your Mac's " +
                      "language and Siri's language must match and be a supported language — set the Mac in General ▸ " +
                      "Language & Region and Siri under Siri ▸ Language (for example English or Svenska). 4) Twin picks " +
                      "the model up automatically; the Assistant status line then says Apple's on-device model. Until " +
                      "then I answer from built-in help, still fully local.",
                  answerSV: "Twin använder Apples on-device-modell när den finns. Sätt upp den så här: 1) Öppna Systeminställningar ▸ Apple Intelligence & Siri (bara Siri i nyare macOS) och slå på / gå med i Siri AI. 2) Modellen laddas ner automatiskt (flera GB, behåll Wi-Fi och ström). 3) Språkregeln: datorns språk och Siris språk måste vara samma och ett stött språk — ställ in datorn under Allmänt ▸ Språk & region och Siri under Siri ▸ Språk (till exempel svenska eller engelska). 4) Twin hittar modellen automatiskt; assistentens statusrad säger då Apples on-device-modell. Tills dess svarar jag från den inbyggda hjälpen, fortfarande helt lokalt."),
        HelpTopic(keywords: ["find", "sök", "search", "hitta", "rekursiv", "alt+f7", "innehåll"],
                  answer: "Cmd+Shift+F (Commands ▸ Find Files) searches recursively under the active pane's folder: by file " +
                      "name and, if you fill in Text in files, inside text files too. Double-click a result to show it in " +
                      "the pane, or use Open to open it. Cmd+F is the quick filter for the current folder only.",
                  answerSV: "Cmd+Shift+F (Commands ▸ Find Files) söker rekursivt under den aktiva panelens mapp: på filnamn och, om du fyller i Text in files, även inuti textfiler. Dubbelklicka på en träff för att visa den i panelen, eller använd Open. Cmd+F är det snabba filtret för bara den aktuella mappen."),
        HelpTopic(keywords: ["view", "visa", "viewer", "f3", "förhandsvisa", "öppna med", "open with",
                              "filtyp", "file type", "standardapp", "default app", "extern editor", "egen editor"],
                  answer: "F3 opens Twin's built-in viewer (text/code with line numbers, Markdown rendered, images, PDF, " +
                      "media, hex for binary files). To connect a file type to another viewer or editor: right-click a file " +
                      "▸ Open With ▸ Koppla filtyp… (guide), or Files ▸ File Type Handlers…. There you pick per extension " +
                      "what F3 shows and what F4/Enter opens — Twin Viewer/Editor, an external app, your own handler " +
                      "(an app or a command like /usr/local/bin/tool {file}), or the macOS default. Setting an editor " +
                      "overrides the macOS default inside Twin.",
                  answerSV: "F3 öppnar Twins inbyggda visare (text/kod med radnummer, Markdown renderad, bilder, PDF, media, hex för binära filer). För att koppla en filtyp till en annan visare eller editor: högerklicka på en fil ▸ Open With ▸ Koppla filtyp… (guide), eller Files ▸ File Type Handlers…. Där väljer du per filändelse vad F3 visar och vad F4/Enter öppnar — Twin Viewer/Editor, en extern app, din egen handler (en app eller ett kommando som /usr/local/bin/tool {file}), eller macOS standardapp. Ett editorval åsidosätter macOS standard i Twin."),
        HelpTopic(keywords: ["size", "storlek", "mappstorlek", "utrymme", "disk"],
                  answer: "Folder sizes are calculated automatically in the background and cached — watch the Size column fill in" +
                      "(… means still counting), then click Size to sort by it. The status bar shows free space on the volume.",
                  answerSV: "Mappstorlekar beräknas automatiskt i bakgrunden och cachas — se Size-kolumnen fyllas i (… betyder att räkning pågår), klicka sedan på Size för att sortera. Statusraden visar ledigt utrymme på volymen."),
        HelpTopic(keywords: ["git", "badge", "märke", "modified", "repo"],
                  answer: "Git badges (Pro) show M for modified and ? for untracked files in the Name column, straight from git" +
                      "status. Twin only reads git — it never commits or changes your repo.",
                  answerSV: "Git-badges (Pro) visar M för ändrade och ? för ospårade filer i Name-kolumnen, direkt från git status. Twin läser bara git — committar eller ändrar aldrig ditt repo."),
        HelpTopic(keywords: ["container", "sandbox", "sandlåda", "inte mina filer", "choose folder", "startmapp", "hemmamapp"],
                  answer: "The orange banner means the pane shows Twin's sandbox container, not your real files. Click Choose" +
                      "Folder in the banner and pick your folder (for example your home folder) — Twin bookmarks it and remembers" +
                      "it per pane.",
                  answerSV: "Den orangea bannern betyder att panelen visar Twins sandbox-container, inte dina riktiga filer. Klicka på Choose Folder i bannern och välj din mapp (till exempel hemmamappen) — Twin bokmärker den och kommer ihåg den per panel."),
        HelpTopic(keywords: ["navigate", "navigera", "tangent", "keyboard", "genväg", "shortcut", "upp en nivå",
                             "backspace", "delete"],
                  answer: "Arrows move, Enter opens, Backspace (the Delete key) goes up one level, Alt+Left/Right walks folder" +
                      "history, Tab switches pane, Cmd+F jumps to the filter, Space is Quick Look. The full map is in" +
                      "Docs/TC-Research.md.",
                  answerSV: "Pilar flyttar, Enter öppnar, Backspace (Delete-tangenten) går upp en nivå, Alt+vänster/höger går i mapphistoriken, Tab byter panel, Cmd+F hoppar till filtret, Space är Quick Look. Hela kartan finns i Docs/TC-Research.md."),
        HelpTopic(keywords: ["pro", "köpa", "pris", "betala", "låst", "unlock"],
                  answer: "Twin Lite is free. Twin Pro (one-time purchase) adds Workspaces, Folder Sync, Batch Rename and Git" +
                      "badges. Locked actions open the paywall where you can buy or restore — Restore Purchases brings back an" +
                      "earlier buy.",
                  answerSV: "Twin Lite är gratis. Twin Pro (engångsköp) lägger till Workspaces, Folder Sync, Batch Rename och Git-badges. Låsta åtgärder öppnar paywallen där du kan köpa eller återställa — Restore Purchases hämtar tillbaka ett tidigare köp."),
        HelpTopic(keywords: ["siri", "shortcut", "genvägar-app", "automation"],
                  answer: "Twin exposes Siri/Shortcuts actions: ask Siri to organize a folder or create an MD5 with Twin, or find" +
                      "Twin in the Shortcuts app. The actions run Twin's own services on the folder or file you give them.",
                  answerSV: "Twin erbjuder Siri/Shortcuts-åtgärder: be Siri organisera en mapp eller skapa en MD5 med Twin, eller hitta Twin i Shortcuts-appen. Åtgärderna kör Twins egna tjänster på mappen eller filen du anger.")
    ]

    public static let fallbackAnswer =
        "I answer questions about using Twin: navigation, copying (Cmd+5/6), sorting, folder sizes, permissions (Cmd+I), " +
        "encrypting (Cmd+Shift+E), zip (Cmd+Shift+C/U), MD5 (Cmd+Shift+M), editing (Cmd+E), tabs (Cmd+T), Workspaces, Folder Sync, " +
        "Batch Rename and Git badges. Try asking about any of those."

    /// Rule-based answer used when no on-device model is available.
    /// Answers in the computer's language (TwinLanguage).
    public static func answer(to question: String) -> String {
        answer(to: question, languageCode: TwinLanguage.currentCode)
    }

    public static func answer(to question: String, languageCode: String) -> String {
        let query = question.lowercased()
        var best: (score: Int, topic: HelpTopic)?
        for topic in topics {
            let score = topic.keywords.filter { query.contains($0) }.count
            if score > 0, score > (best?.score ?? 0) {
                best = (score, topic)
            }
        }
        if let best { return best.topic.localized(code: languageCode) }
        return languageCode == "sv" ? fallbackAnswerSV : fallbackAnswer
    }

    public static let fallbackAnswerSV =
        "Jag svarar på frågor om hur man använder Twin: navigering, kopiering (Cmd+5/6), sortering, " +
        "mappstorlekar, behörigheter (Cmd+I), kryptering (Cmd+Shift+E), zip (Cmd+Shift+C/U), MD5 " +
        "(Cmd+Shift+M), redigering (Cmd+E), flikar (Cmd+T), Workspaces, Folder Sync, Batch Rename " +
        "och Git-badges. Fråga om något av det." 

    /// Suggested starter questions, in the computer's language.
    public static var suggestions: [String] {
        TwinLanguage.isSwedish ? suggestionsSV : suggestionsEN
    }

    public static let suggestionsSV = [
        "Hur kopierar jag filer till andra panelen?",
        "Hur skyddar jag en mapp så bara jag kan läsa den?",
        "Hur sorterar jag den här röriga mappen?",
        "Hur krypterar jag en fil?",
        "Vilken fil tar störst plats här?",
        "Hur sätter jag upp Apple Intelligence?"
    ]

    /// Suggested starter questions for the chat UI.
    public static let suggestionsEN = [
        "How do I copy files to the other pane?",
        "How do I protect a folder so only I can read it?",
        "How do I sort this messy folder?",
        "How do I encrypt a file?",
        "What do the M and ? badges mean?",
        "How do tabs work?",
        "How do I set up Apple Intelligence?"
    ]
}
