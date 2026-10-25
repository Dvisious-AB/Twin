import Foundation

/// The language Twin should speak: the computer's language.
/// macOS already knows it (Locale.preferredLanguages) — Twin
/// answers help questions and instructs the on-device model in
/// that language. Swedish and English have hand-written help;
/// other languages get English fallback text while the model
/// (when available) answers natively in the user's language.
public enum TwinLanguage {
    /// Two-letter code of the computer's first preferred language.
    public static var currentCode: String {
        code(from: Locale.preferredLanguages.first)
    }

    public static func code(from preferred: String?) -> String {
        guard let preferred, !preferred.isEmpty else { return "en" }
        return String(preferred.prefix(2)).lowercased()
    }

    /// Human name, for the model instructions ("answer in Svenska").
    public static var currentName: String {
        Locale.current.localizedString(forLanguageCode: currentCode) ?? "English"
    }

    public static var isSwedish: Bool { currentCode == "sv" }
}
