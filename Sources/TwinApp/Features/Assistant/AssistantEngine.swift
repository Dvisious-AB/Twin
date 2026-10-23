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
            text: "Hi! I can explain how to do file tasks in Twin — copying, sorting, permissions, encryption and more. Ask below," +
                "or tap a suggestion."
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

    func send(_ rawQuestion: String, folder: URL, folderSummary: String) {
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }
        messages.append(Message(isUser: true, text: question))
        isThinking = true
        Task {
            let reply = await answer(question: question, folder: folder, folderSummary: folderSummary)
            messages.append(Message(isUser: false, text: reply))
            isThinking = false
        }
    }

    private func answer(question: String, folder: URL, folderSummary: String) async -> String {
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
                        instructions: "You are Twin's built-in help assistant. Answer briefly, in the user's language when you can" +
                            "tell it, with concrete steps and Twin's shortcuts. Manual:\n\(TwinHelp.manual)"
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

/// One-line folder context for the assistant (counts by category).
enum FolderSummary {
    @MainActor
    static func summary(for viewModel: PaneViewModel) -> String {
        let plan = viewModel.organizePlanSummary
        let folders = viewModel.items.filter(\.isDirectory).count
        let files = viewModel.items.count - folders
        let categories = plan.map { "\($0.count) \($0.category.lowercased())" }.joined(separator: ", ")
        return "\(folders) folders, \(files) files" + (categories.isEmpty ? "" : " (\(categories))")
    }
}
