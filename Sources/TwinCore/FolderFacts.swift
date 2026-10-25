import Foundation

/// Facts about the folder the user is standing in, computed from
/// the real listing — never guessed. The Assistant answers factual
/// questions ("which file takes the most space?", "when was this
/// last used?", "who created these?") from this, and the same data
/// feeds the on-device model as grounded context.
public struct FolderFacts: Sendable {
    public struct FileFact: Sendable {
        public let name: String
        public let isDirectory: Bool
        public let sizeBytes: UInt64
        public let modified: Date
        public let accessed: Date?
        public let owner: String?

        public init(name: String, isDirectory: Bool, sizeBytes: UInt64,
                    modified: Date, accessed: Date?, owner: String?) {
            self.name = name
            self.isDirectory = isDirectory
            self.sizeBytes = sizeBytes
            self.modified = modified
            self.accessed = accessed
            self.owner = owner
        }
    }

    public let files: [FileFact]
    public var totalBytes: UInt64 { files.reduce(0) { $0 + $1.sizeBytes } }

    public init(files: [FileFact]) {
        self.files = files
    }

    public var largest: FileFact? {
        files.filter { !$0.isDirectory }.max { $0.sizeBytes < $1.sizeBytes }
            ?? files.max { $0.sizeBytes < $1.sizeBytes }
    }

    public var mostRecentlyUsed: FileFact? {
        files.compactMap { fact in fact.accessed.map { (fact, $0) } }
            .max { $0.1 < $1.1 }?.0
    }

    public var mostRecentlyModified: FileFact? {
        files.max { $0.modified < $1.modified }
    }

    public var owners: [(owner: String, count: Int)] {
        var counts: [String: Int] = [:]
        for fact in files {
            if let owner = fact.owner { counts[owner, default: 0] += 1 }
        }
        return counts.map { (owner: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    /// Compact grounding text for the on-device model prompt.
    public func contextSummary(folderName: String) -> String {
        var parts = ["Folder \(folderName): \(files.count) item(s), \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)) total."]
        if let largest {
            parts.append("Largest: \(largest.name) (\(ByteCountFormatter.string(fromByteCount: Int64(largest.sizeBytes), countStyle: .file))).")
        }
        let top = files.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(5)
        if !top.isEmpty {
            parts.append("Top by size: " + top.map {
                "\($0.name) \(ByteCountFormatter.string(fromByteCount: Int64($0.sizeBytes), countStyle: .file))"
            }.joined(separator: ", ") + ".")
        }
        if let used = mostRecentlyUsed, let date = used.accessed {
            parts.append("Most recently used: \(used.name) (\(date.formatted(date: .abbreviated, time: .shortened))).")
        }
        if !owners.isEmpty {
            parts.append("Owners: " + owners.map { "\($0.owner) (\($0.count))" }.joined(separator: ", ") + ".")
        }
        return parts.joined(separator: " ")
    }

    /// Deterministic answers for factual questions, in Swedish and
    /// English. Returns nil when the question isn't a fact question
    /// — the model/help then takes over.
    public func answer(to question: String) -> String? {
        answer(to: question, languageCode: TwinLanguage.currentCode)
    }

    public func answer(to question: String, languageCode: String) -> String? {
        let sv = languageCode == "sv"
        let lowered = question.lowercased()

        func hit(_ words: [String]) -> Bool {
            words.contains { lowered.contains($0) }
        }

        if hit(["störst", "största", "largest", "biggest", "tar mest plats", "most space"]) {
            guard let largest else { return sv ? "Mappen är tom — inga filer här." : "The folder is empty — no files here." }
            if sv {
                return "Störst här är \(largest.name) — "
                    + "\(ByteCountFormatter.string(fromByteCount: Int64(largest.sizeBytes), countStyle: .file)) "
                    + "av totalt \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)) i den här mappen."
            }
            let kind = largest.isDirectory ? "folder" : "file"
            return "The largest \(kind) here is \(largest.name) — "
                + "\(ByteCountFormatter.string(fromByteCount: Int64(largest.sizeBytes), countStyle: .file)) "
                + "of \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)) total in this folder."
        }

        let asksLastUsed = hit(["senast använd", "senast öppnad", "last used", "last opened",
                                "recently used", "användes senast"])
            || (lowered.contains("använd") && lowered.contains("senast"))
        if asksLastUsed {
            guard let used = mostRecentlyUsed, let date = used.accessed else {
                return sv ? "Jag har inga senast-använd-datum för filerna här." : "I don't have last-used dates for the files here."
            }
            if sv {
                return "\(used.name) användes senast — \(date.formatted(date: .abbreviated, time: .shortened)). "
                    + "Obs: macOS uppdaterar senast-använd-datum slött, så se det som ungefärligt."
            }
            return "\(used.name) was used most recently — \(date.formatted(date: .abbreviated, time: .shortened)). "
                + "Note: macOS updates last-used dates lazily, so treat it as approximate."
        }

        if hit(["skapade", "skapad av", "vem äger", "ägare", "created by", "who created", "owner", "who owns"]) {
            guard !owners.isEmpty else {
                return sv ? "Jag kunde inte läsa ägarinformation för filerna här."
                    : "I couldn't read owner information for the files here."
            }
            if sv {
                if owners.count == 1, let only = owners.first {
                    return "Allt här (\(only.count) st) ägs av \(only.owner) — på macOS är ägaren normalt "
                        + "användaren som skapade filen."
                }
                return "Ägare här: " + owners.map { "\($0.owner) (\($0.count) st)" }.joined(separator: ", ")
                    + ". På macOS är ägaren normalt användaren som skapade filen."
            }
            if owners.count == 1, let only = owners.first {
                return "Everything here (\(only.count) item(s)) is owned by \(only.owner) — "
                    + "on macOS the owner is normally the user who created the file."
            }
            return "Owners here: " + owners.map { "\($0.owner) (\($0.count) item(s))" }.joined(separator: ", ")
                + ". On macOS the owner is normally the user who created the file."
        }

        if hit(["senast ändrad", "senast modifierad", "last modified", "newest", "nyast", "senast sparad"]) {
            guard let newest = mostRecentlyModified else {
                return sv ? "Mappen är tom — inga filer här." : "The folder is empty — no files here."
            }
            if sv {
                return "\(newest.name) ändrades senast — \(newest.modified.formatted(date: .abbreviated, time: .shortened))."
            }
            return "\(newest.name) changed most recently — \(newest.modified.formatted(date: .abbreviated, time: .shortened))."
        }

        return nil
    }
}
