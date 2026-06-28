import Foundation

enum ClaudeChatError: LocalizedError {
    case badResponse
    case http(Int, String)
    case emptyContent
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .badResponse: String(archie: "errors.bad.server.response")
        case .http(let code, let body): "Claude HTTP \(code): \(String(body.prefix(300)))"
        case .emptyContent: String(archie: "errors.empty.model.response")
        case .invalidJSON: String(archie: "errors.invalid.response.json")
        }
    }
}

final class ClaudeChatAPI: ChatAPISending {
    private enum SessionFactory {
        static let longRunning: URLSession = {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 600
            configuration.timeoutIntervalForResource = 900
            return URLSession(configuration: configuration)
        }()
    }

    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = ClaudeModelPreset.defaultPreset.rawValue, session: URLSession = SessionFactory.longRunning) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func send(_ payload: ChatRequestPayload) async throws -> ChatResponsePayload {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 900
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestDTO(
            model: model,
            max_tokens: 4096,
            system: Self.systemPrompt,
            messages: [
                MessageDTO(role: "user", content: Self.userBlock(payload)),
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeChatError.badResponse }
        guard (200 ... 299).contains(http.statusCode) else {
            throw ClaudeChatError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let completion = try JSONDecoder().decode(CompletionDTO.self, from: data)
        guard let raw = completion.content.first(where: { $0.type == "text" })?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else { throw ClaudeChatError.emptyContent }

        let json = raw.hasPrefix("```") ? Self.unwrapFence(raw) : raw
        guard let jsonData = json.data(using: .utf8) else { throw ClaudeChatError.invalidJSON }
        return try JSONDecoder().decode(ChatResponsePayload.self, from: jsonData)
    }

    private static let systemPrompt = """
    You sit next to the user's terminal. Reply with a single JSON object only (no markdown fences), keys:
    "aiText" (string, user-facing),
    "aiCommand" (string with one shell command, or null if none).
    """

    private static func userBlock(_ p: ChatRequestPayload) -> String {
        """
        Prior chat (newest user line is the current message):
        \(p.conversationTranscript)

        Current user message:
        \(p.userText)

        Terminal buffer:
        \(p.userContext)
        """
    }

    private static func unwrapFence(_ s: String) -> String {
        var lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    private struct RequestDTO: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [MessageDTO]
    }

    private struct MessageDTO: Encodable {
        let role: String
        let content: String
    }

    private struct CompletionDTO: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }

        let content: [ContentBlock]
    }
}
