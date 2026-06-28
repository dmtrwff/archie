import Foundation

enum ChatProvider: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case claude = "claude"
    case deepSeek = "deepseek"

    static let defaultProvider: Self = .openAI

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .openAI: String(archie: "settings.provider.openai")
        case .claude: String(archie: "settings.provider.claude")
        case .deepSeek: String(archie: "settings.provider.deepseek")
        }
    }

    var localizedModelSectionTitle: String {
        switch self {
        case .openAI: String(archie: "settings.openai.model.section")
        case .claude: String(archie: "settings.claude.model.section")
        case .deepSeek: String(archie: "settings.deepseek.model.section")
        }
    }

    var apiKeyFieldTitle: String {
        switch self {
        case .openAI: String(archie: "settings.api.key.field.openai")
        case .claude: String(archie: "settings.api.key.field.claude")
        case .deepSeek: String(archie: "settings.api.key.field.deepseek")
        }
    }

    var apiKeyFootnote: String {
        switch self {
        case .openAI: String(archie: "settings.api.key.footnote.openai")
        case .claude: String(archie: "settings.api.key.footnote.claude")
        case .deepSeek: String(archie: "settings.api.key.footnote.deepseek")
        }
    }

    var environmentVariableName: String {
        switch self {
        case .openAI: "OPENAI_API_KEY"
        case .claude: "ANTHROPIC_API_KEY"
        case .deepSeek: "DEEPSEEK_API_KEY"
        }
    }

    var missingKeyErrorMessage: String {
        switch self {
        case .openAI: String(archie: "errors.missing.api.key.openai")
        case .claude: String(archie: "errors.missing.api.key.claude")
        case .deepSeek: String(archie: "errors.missing.api.key.deepseek")
        }
    }

    static func normalizedStoredID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultProvider.rawValue }
        return ChatProvider(rawValue: trimmed)?.rawValue ?? defaultProvider.rawValue
    }
}
