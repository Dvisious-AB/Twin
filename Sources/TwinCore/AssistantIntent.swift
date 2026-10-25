import Foundation

/// What the user wants Gemma to *do*, parsed from a natural
/// sentence in Swedish or English ("skapa en zip av filerna i den
/// här katalogen", "organize this folder", "find cymbal riser").
/// Rule-based and testable: the docked assistant bar executes
/// these directly; anything else goes to the chat, which answers
/// with the model/help. Destructive wishes are never in this list
/// as direct actions — delete returns a confirmation request.
public enum AssistantIntent: Equatable, Sendable {
    /// Pack the files of the current folder into a zip.
    case packCurrentFolder
    /// Pack the current selection (zip/komprimera + markerade).
    case packSelection
    /// Sort loose files into category folders.
    case organizeFolder
    /// Recursive find with this name text.
    case find(String)
    /// "Which file takes the most space here?"
    case largestFile
    /// Create a folder with this name.
    case createFolder(String)
    /// Move selection to Trash — UI must confirm first.
    case deleteSelection
    /// Not an action: let the chat answer.
    case chat

    public static func parse(_ raw: String) -> AssistantIntent {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = text.lowercased()
        guard !lowered.isEmpty else { return .chat }

        func hit(_ words: [String]) -> Bool {
            words.contains { lowered.contains($0) }
        }

        // Folder creation with a name: "skapa mapp Kvittos 2026",
        // "create folder Invoices". Name = text after the trigger.
        for trigger in ["skapa mapp ", "skapa en mapp ", "ny mapp ", "create folder ", "new folder ", "make folder "] {
            if let range = lowered.range(of: trigger) {
                let name = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return .createFolder(name) }
            }
        }

        if hit(["radera", "ta bort", "delete", "trash"]) && hit(["markerade", "valda", "selection", "filerna", "files"]) {
            return .deleteSelection
        }

        let packWords = ["zip", "packa", "komprimera", "compress", "arkivera", "archive"]
        if hit(packWords) {
            if hit(["markerade", "valda", "selection", "selected"]) {
                return .packSelection
            }
            return .packCurrentFolder
        }

        if hit(["organisera", "organis", "organiz", "sortera filerna", "städa upp", "sort this", "sort the files"]) {
            return .organizeFolder
        }

        if hit(["största", "störst", "largest", "biggest", "tar mest plats", "most space"]) {
            return .largestFile
        }

        // Find: "hitta cymbal", "leta efter riser", "find invoice",
        // "har jag någon sampling…" — the object follows the verb,
        // or the whole question is the object for "har jag/finns det".
        for trigger in ["hitta ", "leta efter ", "leta rätt på ", "sök efter ", "sök ", "find ", "search for ", "look for "] {
            if let range = lowered.range(of: trigger) {
                let object = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "?"))
                if !object.isEmpty { return .find(object) }
            }
        }
        if hit(["har jag", "finns det", "do i have", "is there", "any "]) {
            return .find(text)
        }

        return .chat
    }
}
