import Foundation

struct ChatRequestPayload: Codable {
    let userText: String
    let userContext: String
    let conversationTranscript: String
}

struct ChatResponsePayload: Codable {
    let aiText: String
    let aiCommand: String?
}

protocol ChatAPISending: AnyObject {
    func send(_ payload: ChatRequestPayload) async throws -> ChatResponsePayload
}
