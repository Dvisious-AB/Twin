import Foundation
import TwinCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Chat engine for the Twin Assistant. One persistent on-device language
/// model session (Apple Foundation Models, macOS 26+) with Twin's manual
/// as instructions and folder context per question. Without a model it
/// falls back to TwinHelp's rule-based answers. Always on-device.
@MainActor
final class AssistantChat: ObservableObject {
    struct Message: Identifiable {
        let id = UUID()
        let isUser: Bool
        let text: String
    }

    @Published var messages: [Message] = [
        Message(
            isUser: false,
            text: "Hi, I'm Gemma! I can explain how to do file tasks in Twin — copying, sorting, permissions, encryption " +
                "and more. I can also answer questions about this folder (biggest file, owners, dates) and sort it for you."
        )
    ]
    @Published var isThinking = false

    var modelStatusText: String {
        Self.isModelAvailable
            ? "Apple's on-device model — private and offline."
            : "Built-in help (no on-device model on this Mac) — still fully local."
    }

    static var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Why the model is unavailable, in user language (nil = available).
    static var unavailableGuidance: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "This Mac can't run Apple Intelligence (it needs Apple silicon). Twin Help still answers everything locally."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence is turned off. Turn it on in System Settings — steps below."
            case .unavailable(.modelNotReady):
                return "The model isn't ready yet: it downloads automatically once Siri AI is enabled (or your waitlist spot opens)."
            case .unavailable:
                return "Apple's model isn't available right now. Twin Help still answers everything locally."
            }
        }
        #endif
        return "This system has no on-device model. Twin Help still answers everything locally."
    }

    /// Kom igång: turn on Apple's on-device model for Twin.
    /// The language rule is the step everyone trips on: the Mac's
    /// language and Siri's language must match and be supported.
    static let setupSteps: [String] = [
        "Open System Settings ▸ Apple Intelligence & Siri (just \"Siri\" in newer macOS).",
        "Turn on Apple Intelligence / join Siri AI and wait for your spot — the model then "
            + "downloads automatically (several GB, keep Wi-Fi and power connected).",
        "Language rule: your Mac's language and Siri's language must match. Set both in "
            + "System Settings: General ▸ Language & Region, and Siri ▸ Language. Use a "
            + "supported language (for example English or Svenska).",
        "Come back here — Twin picks the model up automatically. The status line below then says \"Apple's on-device model\"."
    ]

    // LanguageModelSession when the OS provides it; Any to avoid
    // availability-marked stored properties.
    private var sessionBox: Any?

    /// Appends a completed exchange (used when Twin executes a task directly).
    func appendExchange(user: String, assistant: String) {
        messages.append(Message(isUser: true, text: user))
        messages.append(Message(isUser: false, text: assistant))
    }

    func clear() {
        messages = [messages.first].compactMap { $0 }
        sessionBox = nil
    }

    func send(_ rawQuestion: String, folder: URL, folderSummary: String, facts: FolderFacts? = nil) {
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }
        messages.append(Message(isUser: true, text: question))
        isThinking = true
        Task {
            let reply = await answer(question: question, folder: folder, folderSummary: folderSummary, facts: facts)
            messages.append(Message(isUser: false, text: reply))
            isThinking = false
        }
    }

    private func answer(question: String, folder: URL, folderSummary: String,
                        facts: FolderFacts?) async -> String {
        // Factual questions about *this* folder are answered from
        // the real listing — the model never guesses sizes/dates.
        if let factAnswer = facts?.answer(to: question) {
            return factAnswer
        }
        if let modelReply = await modelAnswer(question: question, folder: folder, folderSummary: folderSummary) {
            return modelReply
        }
        return TwinHelp.answer(to: question)
    }

    private func modelAnswer(question: String, folder: URL, folderSummary: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), Self.isModelAvailable {
            do {
                let session: LanguageModelSession
                if let existing = sessionBox as? LanguageModelSession {
                    session = existing
                } else {
                    let created = LanguageModelSession(
                        instructions: "You are Twin's built-in help assistant, named Gemma. The computer's language is "
                            + "\(TwinLanguage.currentName) — always answer in that language. Answer briefly, with concrete "
                            + "steps and Twin's shortcuts. Use the folder facts given in the prompt for size/date/owner "
                            + "questions; never invent file names or sizes. Manual:\n\(TwinHelp.manual)"
                    )
                    sessionBox = created
                    session = created
                }
                let prompt = "Current folder: \(folder.path). Contents summary: \(folderSummary). Question: \(question)"
                return try await session.respond(to: prompt).content
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

/// Folder context for the assistant: category counts plus the
/// grounded FolderFacts (sizes, dates, owners) from the listing.
enum FolderSummary {
    @MainActor
    static func summary(for viewModel: PaneViewModel) -> String {
        let plan = viewModel.organizePlanSummary
        let folders = viewModel.items.filter(\.isDirectory).count
        let files = viewModel.items.count - folders
        let categories = plan.map { "\($0.count) \($0.category.lowercased())" }.joined(separator: ", ")
        return "\(folders) folders, \(files) files" + (categories.isEmpty ? "" : " (\(categories))")
            + " " + facts(for: viewModel).contextSummary(folderName: viewModel.currentURL.lastPathComponent)
    }

    @MainActor
    static func facts(for viewModel: PaneViewModel) -> FolderFacts {
        FolderFacts(files: viewModel.items.map { item in
            FolderFacts.FileFact(
                name: item.name,
                isDirectory: item.isDirectory,
                sizeBytes: item.isDirectory
                    ? (viewModel.directorySizes[item.url.path] ?? 0)
                    : item.size,
                modified: item.modifiedDate,
                accessed: item.accessedDate,
                owner: item.owner)
        })
    }
}
