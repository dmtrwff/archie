import Foundation

extension UserDefaults {
    static var shared: UserDefaults { .standard }

    enum Keys {
        static let appearanceThemeID = "Archie.themeID.v1"
        static let chatProviderID = "Archie.chat.provider.v1"
        static let openAIModelID = "Archie.openai.model.v1"
        static let claudeModelID = "Archie.claude.model.v1"
        static let deepSeekModelID = "Archie.deepseek.model.v1"
    }

    var chatProvider: ChatProvider {
        get {
            ChatProvider(rawValue: ChatProvider.normalizedStoredID(string(forKey: Keys.chatProviderID) ?? ""))
                ?? .defaultProvider
        }
        set { set(newValue.rawValue, forKey: Keys.chatProviderID) }
    }

    /// Selected Chat Completions model (`gpt-4o-mini`, etc.).
    var openAIModelIdentifier: String {
        get { OpenAIModelPreset.normalizedStoredID(string(forKey: Keys.openAIModelID) ?? "") }
        set { set(OpenAIModelPreset.normalizedStoredID(newValue), forKey: Keys.openAIModelID) }
    }

    var claudeModelIdentifier: String {
        get { ClaudeModelPreset.normalizedStoredID(string(forKey: Keys.claudeModelID) ?? "") }
        set { set(ClaudeModelPreset.normalizedStoredID(newValue), forKey: Keys.claudeModelID) }
    }

    var deepSeekModelIdentifier: String {
        get { DeepSeekModelPreset.normalizedStoredID(string(forKey: Keys.deepSeekModelID) ?? "") }
        set { set(DeepSeekModelPreset.normalizedStoredID(newValue), forKey: Keys.deepSeekModelID) }
    }

    func modelIdentifier(for provider: ChatProvider) -> String {
        switch provider {
        case .openAI: openAIModelIdentifier
        case .claude: claudeModelIdentifier
        case .deepSeek: deepSeekModelIdentifier
        }
    }

    var appearanceTheme: VisualAppearanceTheme {
        get {
            if let id = string(forKey: Keys.appearanceThemeID), !id.isEmpty {
                return VisualAppearanceTheme.theme(id: id)
            }
            return .matrix
        }
        set {
            set(newValue.persistenceKey, forKey: Keys.appearanceThemeID)
        }
    }
}
