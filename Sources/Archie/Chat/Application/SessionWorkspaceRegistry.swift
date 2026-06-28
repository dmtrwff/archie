import Combine
import Foundation

@MainActor
final class SessionWorkspaceRegistry: ObservableObject {
    private var bridges: [UUID: TerminalSessionBridge] = [:]
    @Published private(set) var assistantThinkingSessionIDs: Set<UUID> = []

    func bridge(for session: ChatSessionRecord) -> TerminalSessionBridge {
        let id = session.id
        if let existing = bridges[id] { return existing }
        let bridge = TerminalSessionBridge()
        bridges[id] = bridge
        return bridge
    }

    func releaseBridge(sessionID: UUID) {
        bridges[sessionID]?.terminateTerminal()
        bridges[sessionID] = nil
    }

    func setAssistantThinking(_ thinking: Bool, sessionID: UUID) {
        if thinking {
            assistantThinkingSessionIDs.insert(sessionID)
        } else {
            assistantThinkingSessionIDs.remove(sessionID)
        }
    }

    func isAssistantThinking(sessionID: UUID) -> Bool {
        assistantThinkingSessionIDs.contains(sessionID)
    }
}
