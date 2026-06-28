import SwiftUI

struct OpenAISettingsView: View {
    @EnvironmentObject private var chatRouter: ChatRouter
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage(UserDefaults.Keys.chatProviderID) private var storedChatProviderID: String = ChatProvider.defaultProvider.rawValue
    @AppStorage(UserDefaults.Keys.openAIModelID) private var storedOpenAIModelID: String = OpenAIModelPreset.defaultPreset.rawValue
    @AppStorage(UserDefaults.Keys.claudeModelID) private var storedClaudeModelID: String = ClaudeModelPreset.defaultPreset.rawValue
    @AppStorage(UserDefaults.Keys.deepSeekModelID) private var storedDeepSeekModelID: String = DeepSeekModelPreset.defaultPreset.rawValue
    @State private var tokenDraft = ""
    @State private var keychainError: String?

    private var selectedProvider: ChatProvider {
        ChatProvider(rawValue: ChatProvider.normalizedStoredID(storedChatProviderID)) ?? .defaultProvider
    }

    var body: some View {
        Form {
            Section(String(archie: "appearance.settings.section")) {
                Picker(String(archie: "appearance.theme.picker"), selection: $themeManager.theme) {
                    ForEach(VisualAppearanceTheme.allCases) { theme in
                        Label(theme.title, systemImage: theme.previewSystemImage)
                            .tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section(String(archie: "settings.chat.provider.section")) {
                Picker(String(archie: "settings.chat.provider.picker"), selection: $storedChatProviderID) {
                    ForEach(ChatProvider.allCases) { provider in
                        Text(provider.localizedTitle).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: storedChatProviderID) { _, _ in
                    chatRouter.invalidateClient()
                    reloadTokenDraft()
                }
            }

            Section(selectedProvider.localizedModelSectionTitle) {
                switch selectedProvider {
                case .openAI:
                    modelPicker(
                        selection: $storedOpenAIModelID,
                        presets: OpenAIModelPreset.allCases.map { ($0.rawValue, $0.localizedTitle) }
                    )
                case .claude:
                    modelPicker(
                        selection: $storedClaudeModelID,
                        presets: ClaudeModelPreset.allCases.map { ($0.rawValue, $0.localizedTitle) }
                    )
                case .deepSeek:
                    modelPicker(
                        selection: $storedDeepSeekModelID,
                        presets: DeepSeekModelPreset.allCases.map { ($0.rawValue, $0.localizedTitle) }
                    )
                }
            }

            Section {
                SecureField(selectedProvider.apiKeyFieldTitle, text: $tokenDraft)
                    .textFieldStyle(.roundedBorder)
                Text(selectedProvider.apiKeyFootnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Button(String(archie: "settings.save.keychain")) {
                    keychainError = nil
                    do {
                        try saveKeychain(tokenDraft)
                        chatRouter.invalidateClient()
                    } catch {
                        keychainError = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)

                Button(String(archie: "settings.delete.keychain"), role: .destructive) {
                    keychainError = nil
                    do {
                        try deleteKeychain()
                        tokenDraft = ""
                        chatRouter.invalidateClient()
                    } catch {
                        keychainError = error.localizedDescription
                    }
                }
            }

            if let keychainError {
                Section {
                    Text(keychainError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .padding(16)
        .frame(minWidth: 440, minHeight: 280)
        .preferredChromeColorScheme(for: themeManager.theme)
        .onAppear {
            storedChatProviderID = ChatProvider.normalizedStoredID(storedChatProviderID)
            storedOpenAIModelID = OpenAIModelPreset.normalizedStoredID(storedOpenAIModelID)
            storedClaudeModelID = ClaudeModelPreset.normalizedStoredID(storedClaudeModelID)
            storedDeepSeekModelID = DeepSeekModelPreset.normalizedStoredID(storedDeepSeekModelID)
            reloadTokenDraft()
        }
    }

    @ViewBuilder
    private func modelPicker(selection: Binding<String>, presets: [(String, String)]) -> some View {
        Picker(String(archie: "settings.openai.model.picker"), selection: selection) {
            ForEach(presets, id: \.0) { preset in
                Text(preset.1).tag(preset.0)
            }
        }
        .pickerStyle(.radioGroup)
        .onChange(of: selection.wrappedValue) { _, _ in
            chatRouter.invalidateClient()
        }
    }

    private func reloadTokenDraft() {
        tokenDraft = loadKeychain() ?? ""
    }

    private func loadKeychain() -> String? {
        switch selectedProvider {
        case .openAI: OpenAIKeychain.load()
        case .claude: ClaudeKeychain.load()
        case .deepSeek: DeepSeekKeychain.load()
        }
    }

    private func saveKeychain(_ token: String) throws {
        switch selectedProvider {
        case .openAI: try OpenAIKeychain.save(token)
        case .claude: try ClaudeKeychain.save(token)
        case .deepSeek: try DeepSeekKeychain.save(token)
        }
    }

    private func deleteKeychain() throws {
        switch selectedProvider {
        case .openAI: try OpenAIKeychain.delete()
        case .claude: try ClaudeKeychain.delete()
        case .deepSeek: try DeepSeekKeychain.delete()
        }
    }
}
