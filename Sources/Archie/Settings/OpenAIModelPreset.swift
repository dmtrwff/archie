import Foundation

/// Model identifiers for OpenAI Chat Completions (`/v1/chat/completions`).
/// Curated from [All models](https://developers.openai.com/api/docs/models/all).
enum OpenAIModelPreset: String, CaseIterable, Identifiable {
    /// Strong mini tier for coding, computer use, and subagents.
    case gpt54Mini = "gpt-5.4-mini"
    /// More affordable frontier tier for coding and professional work.
    case gpt54 = "gpt-5.4"
    /// Most capable tier for coding and professional work.
    case gpt55 = "gpt-5.5"

    static let defaultPreset: Self = .gpt54Mini

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .gpt54Mini: String(archie: "openai.model.gpt54_mini")
        case .gpt54: String(archie: "openai.model.gpt54")
        case .gpt55: String(archie: "openai.model.gpt55")
        }
    }

    /// Returns a supported API id, falling back to the default when storage is empty or unknown.
    static func normalizedStoredID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultPreset.rawValue }
        return OpenAIModelPreset(rawValue: trimmed)?.rawValue ?? defaultPreset.rawValue
    }
}
