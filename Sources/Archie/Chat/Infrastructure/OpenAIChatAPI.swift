import Foundation

enum OpenAIChatError: LocalizedError {
    case badResponse
    case http(Int, String)
    case emptyChoices
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .badResponse: String(archie: "errors.bad.server.response")
        case .http(let code, let body): "OpenAI HTTP \(code): \(String(body.prefix(300)))"
        case .emptyChoices: String(archie: "errors.empty.model.response")
        case .invalidJSON: String(archie: "errors.invalid.response.json")
        }
    }
}

final class OpenAIChatAPI: ChatAPISending {
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

    init(apiKey: String, model: String = OpenAIModelPreset.defaultPreset.rawValue, session: URLSession = SessionFactory.longRunning) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func send(_ payload: ChatRequestPayload) async throws -> ChatResponsePayload {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 900
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestDTO(
            model: model,
            messages: [
                MessageDTO(role: "system", content: Self.systemPrompt),
                MessageDTO(role: "user", content: Self.userBlock(payload)),
            ],
            response_format: .init(type: "json_object")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenAIChatError.badResponse }
        guard (200 ... 299).contains(http.statusCode) else {
            throw OpenAIChatError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let completion = try JSONDecoder().decode(CompletionDTO.self, from: data)
        guard let raw = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { throw OpenAIChatError.emptyChoices }

        let json = raw.hasPrefix("```") ? Self.unwrapFence(raw) : raw
        guard let jsonData = json.data(using: .utf8) else { throw OpenAIChatError.invalidJSON }
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
        let messages: [MessageDTO]
        let response_format: ResponseFormatDTO
    }

    private struct MessageDTO: Encodable {
        let role: String
        let content: String
    }

    private struct ResponseFormatDTO: Encodable {
        let type: String
    }

    private struct CompletionDTO: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String?
                let content: String?
            }

            let message: Message
        }

        let choices: [Choice]
    }
}
