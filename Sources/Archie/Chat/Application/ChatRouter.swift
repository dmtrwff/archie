import Combine
import Foundation

enum ChatRouterError: LocalizedError {
    case missingAPIKey(ChatProvider)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            provider.missingKeyErrorMessage
        }
    }
}

/// API key from Keychain, otherwise provider env var. Cached until `invalidateClient()`.
final class ChatRouter: ObservableObject, ChatAPISending {
    private var client: ChatAPISending?
    private var apiKeyMemo: [ChatProvider: String] = [:]
    private var clientModelID: String?
    private var clientProvider: ChatProvider?

    func invalidateClient() {
        client = nil
        apiKeyMemo = [:]
        clientModelID = nil
        clientProvider = nil
    }

    func send(_ payload: ChatRequestPayload) async throws -> ChatResponsePayload {
        let provider = UserDefaults.shared.chatProvider
        let key = resolveAPIKey(for: provider)
        guard !key.isEmpty else { throw ChatRouterError.missingAPIKey(provider) }
        let modelID = UserDefaults.shared.modelIdentifier(for: provider)
        if client == nil || clientProvider != provider || clientModelID != modelID {
            client = makeClient(provider: provider, apiKey: key, model: modelID)
            clientProvider = provider
            clientModelID = modelID
        }
        return try await client!.send(payload)
    }

    private func makeClient(provider: ChatProvider, apiKey: String, model: String) -> ChatAPISending {
        switch provider {
        case .openAI:
            OpenAIChatAPI(apiKey: apiKey, model: model)
        case .claude:
            ClaudeChatAPI(apiKey: apiKey, model: model)
        case .deepSeek:
            DeepSeekChatAPI(apiKey: apiKey, model: model)
        }
    }

    private func resolveAPIKey(for provider: ChatProvider) -> String {
        if let memo = apiKeyMemo[provider] { return memo }
        let key =
            nonEmptyTrimmed(keychainValue(for: provider))
            ?? nonEmptyTrimmed(ProcessInfo.processInfo.environment[provider.environmentVariableName])
            ?? ""
        apiKeyMemo[provider] = key
        return key
    }

    private func keychainValue(for provider: ChatProvider) -> String? {
        switch provider {
        case .openAI: OpenAIKeychain.load()
        case .claude: ClaudeKeychain.load()
        case .deepSeek: DeepSeekKeychain.load()
        }
    }

    private func nonEmptyTrimmed(_ raw: String?) -> String? {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}
