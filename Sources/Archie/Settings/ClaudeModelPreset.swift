import Foundation

/// Model identifiers for Anthropic Messages API (`/v1/messages`).
enum ClaudeModelPreset: String, CaseIterable, Identifiable {
    case sonnet = "claude-sonnet-4-20250514"
    case opus = "claude-opus-4-20250514"
    case haiku = "claude-haiku-4-20250414"

    static let defaultPreset: Self = .sonnet

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .sonnet: String(archie: "claude.model.sonnet")
        case .opus: String(archie: "claude.model.opus")
        case .haiku: String(archie: "claude.model.haiku")
        }
    }

    static func normalizedStoredID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultPreset.rawValue }
        return ClaudeModelPreset(rawValue: trimmed)?.rawValue ?? defaultPreset.rawValue
    }
}
