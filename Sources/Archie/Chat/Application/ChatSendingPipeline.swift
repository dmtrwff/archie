import Foundation
import SwiftData

@MainActor
enum ChatSendingPipeline {
    private static let draftSessionName = String(archie: "session.draft.displayName")
    private static let maxConversationTranscriptUTF8Bytes = 220_000
    private static let maxTerminalContextUTF8Bytes = 512_000

    static func appendUserMessage(
        modelContext: ModelContext,
        chatSession: ChatSessionRecord,
        text: String,
        terminalSnapshotUTF8: String?
    ) throws {
        updateSessionNameIfNeeded(chatSession: chatSession, firstUserMessage: text)
        try ensureSessionIsPersisted(modelContext: modelContext, chatSession: chatSession)
        let row = ChatMessageRecord(
            role: .user,
            text: text,
            shellCommand: nil,
            terminalSnapshotUTF8: terminalSnapshotUTF8,
            session: chatSession
        )
        modelContext.insert(row)
        try modelContext.save()
    }

    /// Snapshot pair used when saving the user row and when calling OpenAI (single capture per send).
    static func terminalSnapshotParts(from bridge: TerminalSessionBridge) -> (stored: String?, forAPI: String) {
        let snapshotRaw = bridge.consoleSnapshotUTF8()
        let trimmedTerminal = snapshotRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshotStored = TerminalSnapshotStorage.prepare(snapshotRaw)
        let snapshotForAPI = snapshotStored ?? trimmedTerminal
        return (snapshotStored, snapshotForAPI)
    }

    /// Snapshot terminal once, persist the user row, then request an assistant reply (same path as the chat composer).
    static func sendTurnWithCapturedTerminal(
        modelContext: ModelContext,
        chatSession: ChatSessionRecord,
        api: ChatAPISending,
        bridge: TerminalSessionBridge,
        userText: String,
        sessionWasInvalidated: @MainActor () -> Bool
    ) async throws {
        let parts = terminalSnapshotParts(from: bridge)

        try appendUserMessage(
            modelContext: modelContext,
            chatSession: chatSession,
            text: userText,
            terminalSnapshotUTF8: parts.stored
        )

        do {
            try Task.checkCancellation()
            try await fetchAndReply(
                modelContext: modelContext,
                chatSession: chatSession,
                api: api,
                userMessageText: userText,
                terminalContextUTF8: parts.forAPI,
                sessionWasInvalidated: sessionWasInvalidated
            )
        } catch {
            if isCancellationLike(error), sessionWasInvalidated() == false {
                try? removeLastUserMessageIfMatches(modelContext: modelContext, chatSession: chatSession, text: userText)
            }
            throw error
        }
    }

    static func isCancellationLike(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        return false
    }

    static func fetchAndReply(
        modelContext: ModelContext,
        chatSession: ChatSessionRecord,
        api: ChatAPISending,
        userMessageText: String,
        terminalContextUTF8: String,
        sessionWasInvalidated: @MainActor () -> Bool
    ) async throws {
        let rows = chatSession.messages.sorted { $0.createdAt < $1.createdAt }
        let transcript = UTF8Truncation.cappedTailWithBanner(
            ChatMessageRecord.conversationTranscript(rows: rows),
            maxUTF8Bytes: maxConversationTranscriptUTF8Bytes,
            banner: String(archie: "transcript.truncation.banner")
        )
        let terminalContext = UTF8Truncation.cappedTailWithBanner(
            terminalContextUTF8,
            maxUTF8Bytes: maxTerminalContextUTF8Bytes,
            banner: String(archie: "terminal.snapshot.truncation.banner")
        )
        let payload = ChatRequestPayload(
            userText: userMessageText,
            userContext: terminalContext,
            conversationTranscript: transcript
        )
        try Task.checkCancellation()
        let response = try await api.send(payload)
        try Task.checkCancellation()
        if sessionWasInvalidated() { return }
        let cmd = response.aiCommand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let assistant = ChatMessageRecord(
            role: .assistant,
            text: response.aiText,
            shellCommand: cmd.isEmpty ? nil : cmd,
            session: chatSession
        )
        modelContext.insert(assistant)
        try modelContext.save()
    }

    static func appendAssistantError(
        modelContext: ModelContext,
        chatSession: ChatSessionRecord,
        message: String,
        sessionWasInvalidated: @MainActor () -> Bool
    ) throws {
        if sessionWasInvalidated() { return }
        let row = ChatMessageRecord(role: .assistant, text: message, shellCommand: nil, session: chatSession)
        modelContext.insert(row)
        try modelContext.save()
    }

    static func removeLastUserMessageIfMatches(modelContext: ModelContext, chatSession: ChatSessionRecord, text: String) throws {
        let rows = chatSession.messages.sorted { $0.createdAt > $1.createdAt }
        guard let last = rows.first, last.displayRole == .user, last.text == text else { return }
        modelContext.delete(last)
        try modelContext.save()
    }

    static func persistSessionIfNeeded(modelContext: ModelContext, chatSession: ChatSessionRecord) throws {
        try ensureSessionIsPersisted(modelContext: modelContext, chatSession: chatSession)
    }

    private static func ensureSessionIsPersisted(modelContext: ModelContext, chatSession: ChatSessionRecord) throws {
        let sid = chatSession.id
        let descriptor = FetchDescriptor<ChatSessionRecord>(
            predicate: #Predicate<ChatSessionRecord> { $0.id == sid }
        )
        let exists = try modelContext.fetch(descriptor).isEmpty == false
        if !exists {
            modelContext.insert(chatSession)
        }
    }

    private static func updateSessionNameIfNeeded(chatSession: ChatSessionRecord, firstUserMessage: String) {
        guard chatSession.name == draftSessionName else { return }
        let compact = firstUserMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !compact.isEmpty else { return }
        chatSession.name = String(compact.prefix(48))
    }

}
