import Foundation

/// Gemma's smart find: "har jag någon sampling som är en cymbal
/// raiser?" The question becomes token groups with synonyms
/// (raiser → riser/swell/crescendo), searched by file name across
/// the user's likely folders, ranked by how many groups hit.
/// Audio intent (sample/sampling/ljud) prefers audio files but
/// never hides name hits in sample-pack folders.
public enum AssistantFind {
    public struct Scored: Identifiable, Sendable {
        public var id: String { match.url.path }
        public let match: FileSearchService.Match
        public let matchedGroups: Int
        public let score: Int
    }

    /// Token groups: each group is synonyms meaning one concept.
    public static let synonymGroups: [[String]] = [
        ["cymbal", "cym", "crash", "ride", "hihat", "hat"],
        ["raiser", "riser", "swell", "crescendo", "uplifter", "uplift", "buildup", "sweep"],
        ["kick", "trumma", "bassdrum", "bd"],
        ["snare", "virvel", "sd", "clap"],
        ["piano", "keys", "klaviatur"],
        ["gitarr", "guitar", "gtr"],
        ["bas", "bass", "sub"],
        ["sång", "vocal", "vox", "voice", "röst"],
        ["stråkar", "strings", "violin"],
        ["synth", "synt", "pad", "lead"]
    ]

    private static let stopwords: Set<String> = [
        "har", "jag", "någon", "något", "några", "en", "ett", "på", "min", "mina", "dator",
        "som", "är", "det", "finns", "i", "av", "för", "med", "till", "katalog", "mapp",
        "fil", "filer", "sampling", "samplingar", "sample", "samples", "ljud", "audio",
        "do", "have", "any", "a", "the", "on", "my", "computer", "file", "files", "there",
        "is", "find", "me", "looking", "for", "search", "hitta", "leta", "sök", "rätt"
    ]

    /// Words that mark audio intent (filter preference, not tokens).
    private static let audioWords: Set<String> = [
        "sampling", "samplingar", "sample", "samples", "ljud", "audio", "sound", "musik", "music"
    ]

    public struct Request: Sendable {
        public let groups: [[String]]
        public let wantsAudio: Bool
        public var flatTokens: [String] { groups.flatMap { $0 } }
        public var isEmpty: Bool { groups.isEmpty }
    }

    public static func request(from question: String) -> Request {
        let words = question.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
        let wantsAudio = words.contains { audioWords.contains($0) }
        var groups: [[String]] = []
        for word in words where !stopwords.contains(word) {
            if let group = synonymGroups.first(where: { $0.contains(word) }) {
                if !groups.contains(group) { groups.append(group) }
            } else {
                groups.append([word])
            }
        }
        return Request(groups: groups, wantsAudio: wantsAudio)
    }

    /// Searches roots (first = prioritized) and ranks matches.
    public static func search(in roots: [URL], request: Request, maxResults: Int = 20) -> [Scored] {
        guard !request.isEmpty else { return [] }
        var query = FileSearchService.Query()
        query.nameAnyTokens = request.flatTokens
        query.maxResults = 300

        var scored: [Scored] = []
        for root in roots {
            let outcome = FileSearchService.search(in: root, query: query)
            for match in outcome.matches where !match.isDirectory {
                let name = match.url.lastPathComponent.lowercased()
                let parent = match.url.deletingLastPathComponent().lastPathComponent.lowercased()
                var matched = 0
                for group in request.groups
                where group.contains(where: { name.contains($0) || parent.contains($0) }) {
                    matched += 1
                }
                guard matched > 0 else { continue }
                var score = matched * 100
                let kind = FileTypeRegistry.kind(for: match.url)
                if kind == .audio { score += 40 }
                if parent.contains("sample") || name.contains("sample") { score += 15 }
                if !request.wantsAudio || kind == .audio || parent.contains("sample") {
                    scored.append(Scored(match: match, matchedGroups: matched, score: score))
                }
            }
        }
        return Array(scored.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.match.url.path < $1.match.url.path
        }.prefix(maxResults))
    }
}
