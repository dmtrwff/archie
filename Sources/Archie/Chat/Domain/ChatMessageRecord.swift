import Foundation
import SwiftData

enum ChatMessageDisplayRole: String, Codable {
    case user
    case assistant
}

@Model
final class ChatSessionRecord {
    var id: UUID
    var name: String
    var createdAt: Date
    var isPinned: Bool

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageRecord.session)
    var messages: [ChatMessageRecord]

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, isPinned: Bool = false) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.messages = []
    }
}

@Model
final class ChatMessageRecord {
    var roleRaw: String
    var text: String
    var shellCommand: String?
    /// Terminal buffer captured when this **user** message was sent (paired with chat history).
    var terminalSnapshotUTF8: String?
    var createdAt: Date
    var session: ChatSessionRecord?

    init(
        role: ChatMessageDisplayRole,
        text: String,
        shellCommand: String? = nil,
        terminalSnapshotUTF8: String? = nil,
        createdAt: Date = .now,
        session: ChatSessionRecord? = nil
    ) {
        self.roleRaw = role.rawValue
        self.text = text
        self.shellCommand = shellCommand
        self.terminalSnapshotUTF8 = terminalSnapshotUTF8
        self.createdAt = createdAt
        self.session = session
    }

    var displayRole: ChatMessageDisplayRole {
        ChatMessageDisplayRole(rawValue: roleRaw) ?? .assistant
    }
}

extension ChatMessageRecord {
    static func conversationTranscript(rows: [ChatMessageRecord]) -> String {
        rows
            .sorted { $0.createdAt < $1.createdAt }
            .map { row in
                switch row.displayRole {
                case .user: "\(String(archie: "transcript.user.prefix")): \(row.text)"
                case .assistant: "\(String(archie: "transcript.assistant.prefix")): \(row.text)"
                }
            }
            .joined(separator: "\n\n")
    }
}
