import Foundation

/// Model identifiers for DeepSeek Chat Completions (`/chat/completions`).
enum DeepSeekModelPreset: String, CaseIterable, Identifiable {
    case chat = "deepseek-chat"
    case reasoner = "deepseek-reasoner"

    static let defaultPreset: Self = .chat

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .chat: String(archie: "deepseek.model.chat")
        case .reasoner: String(archie: "deepseek.model.reasoner")
        }
    }

    static func normalizedStoredID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultPreset.rawValue }
        return DeepSeekModelPreset(rawValue: trimmed)?.rawValue ?? defaultPreset.rawValue
    }
}
