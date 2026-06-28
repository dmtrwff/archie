import AppKit
import SwiftData
import SwiftUI

struct ChatSidePanel: View {
    @Bindable var chatSession: ChatSessionRecord
    @ObservedObject var bridge: TerminalSessionBridge
    let api: ChatAPISending
    @ObservedObject var sessionRegistry: SessionWorkspaceRegistry
    let onDeleteSession: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext

    @Query private var messages: [ChatMessageRecord]

    @State private var draft = ""
    @State private var isSending = false
    @State private var sendTask: Task<Void, Never>?
    @State private var chatSessionEpoch = 0
    @FocusState private var inputFocused: Bool

    init(
        chatSession: ChatSessionRecord,
        bridge: TerminalSessionBridge,
        api: ChatAPISending,
        sessionRegistry: SessionWorkspaceRegistry,
        onDeleteSession: @escaping () -> Void
    ) {
        self._chatSession = Bindable(chatSession)
        self.bridge = bridge
        self.api = api
        self.sessionRegistry = sessionRegistry
        self.onDeleteSession = onDeleteSession
        let sid = chatSession.id
        _messages = Query(
            filter: #Predicate<ChatMessageRecord> { row in
                row.session?.id == sid
            },
            sort: \ChatMessageRecord.createdAt,
            order: .forward
        )
    }

    private var palette: ThemePalette { themeManager.palette }

    private static let squircleInnerCornerRadius: CGFloat = 16
    private static let squircleNestedPadding: CGFloat = 8
    private static let squircleOuterCornerRadius: CGFloat = squircleInnerCornerRadius + squircleNestedPadding
    private static let headerNavBubbleHeight: CGFloat = 46
    /// Padding below the last message inside the scroll area (above the composer).
    private static let scrollBottomInset: CGFloat = 28
    private static let chatScrollBottomID = "archie.chat.scroll.bottom"

    private static var squircleInnerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: squircleInnerCornerRadius, style: .continuous)
    }

    private static var squircleOuterShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: squircleOuterCornerRadius, style: .continuous)
    }

    private var messagesAnimationSignature: String {
        guard let last = messages.last else { return "0" }
        return "\(messages.count)_\(String(describing: last.persistentModelID))_\(last.createdAt.timeIntervalSinceReferenceDate)"
    }

    private func scrollChatToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard !messages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(Self.chatScrollBottomID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.chatScrollBottomID, anchor: .bottom)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chatHeaderSection

            // Normal scroll order (no vertical flip): flipped stacks break trackpad scrolling and
            // height measurement for long multiline messages on macOS.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(messages, id: \.persistentModelID) { msg in
                            messageGroup(msg)
                                .id(msg.persistentModelID)
                                .transition(.opacity)
                        }
                        Color.clear
                            .frame(height: Self.scrollBottomInset)
                            .accessibilityHidden(true)
                            .id(Self.chatScrollBottomID)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.22), value: messagesAnimationSignature)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollIndicators(.hidden)
                .background(palette.canvasBackground)
                .onAppear {
                    scrollChatToBottom(proxy: proxy, animated: false)
                    DispatchQueue.main.async {
                        scrollChatToBottom(proxy: proxy, animated: false)
                    }
                }
                .onChange(of: messagesAnimationSignature) { _, _ in
                    DispatchQueue.main.async {
                        scrollChatToBottom(proxy: proxy, animated: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if isSending {
                    HStack(alignment: .center, spacing: 10) {
                        Text(String(archie: "chat.assistant.typing"))
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                        Spacer(minLength: 8)
                        Button(String(archie: "chat.cancel")) {
                            cancelSend()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .keyboardShortcut(.escape, modifiers: [])
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 16)
                }

                inputComposer
            }
            .padding(.bottom, 12)
            .padding(.top, 8)
            .background(palette.canvasBackground)
        }
        .frame(minWidth: 240, idealWidth: 340, maxWidth: .infinity)
        .background(palette.canvasBackground)
    }

    private var chatHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sessionTitleBubble
            pinnedBubble
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sessionTitleBubble: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(archie: "chat.panel.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                Text(chatSession.name)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button {
                deleteSessionFromChatHeader()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(3)
                    .background(.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(String(archie: "chat.delete.help"))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Self.headerNavBubbleHeight)
        .background(palette.elevatedSurface)
        .clipShape(Self.squircleInnerShape)
        .overlay(
            Self.squircleInnerShape
                .strokeBorder(palette.border, lineWidth: 1)
        )
    }

    private var pinnedBubble: some View {
        HStack(spacing: 10) {
            Text(String(archie: "chat.pinned.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            Spacer(minLength: 12)
            Toggle("", isOn: $chatSession.isPinned)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(String(archie: "chat.pinned.help"))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Self.headerNavBubbleHeight)
        .background(palette.elevatedSurface)
        .clipShape(Self.squircleInnerShape)
        .overlay(
            Self.squircleInnerShape
                .strokeBorder(palette.border, lineWidth: 1)
        )
        .onChange(of: chatSession.isPinned) { _, _ in
            persistPinState()
        }
    }

    private func persistPinState() {
        try? ChatSendingPipeline.persistSessionIfNeeded(modelContext: modelContext, chatSession: chatSession)
        try? modelContext.save()
    }

    private func deleteSessionFromChatHeader() {
        chatSessionEpoch += 1
        sendTask?.cancel()
        sendTask = nil
        isSending = false
        sessionRegistry.setAssistantThinking(false, sessionID: chatSession.id)
        draft = ""
        onDeleteSession()
    }

    @ViewBuilder
    private func messageGroup(_ msg: ChatMessageRecord) -> some View {
        switch msg.displayRole {
        case .assistant:
            assistantReplyCell(msg)
        case .user:
            HStack {
                Spacer(minLength: 28)
                userBubble(text: msg.text, terminalSnapshot: msg.terminalSnapshotUTF8)
            }
        }
    }

    private func assistantReplyCell(_ msg: ChatMessageRecord) -> some View {
        let cmd = (msg.shellCommand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCommand = !cmd.isEmpty

        return HStack {
            VStack(alignment: .leading, spacing: 8) {
                chatMessageText(msg.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasCommand {
                    Button {
                        bridge.runShellInput(cmd)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(cmd)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(palette.primaryText)
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(palette.elevatedSurface)
                        .clipShape(Self.squircleInnerShape)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(String(archie: "chat.send.command.help"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Spacer(minLength: 28)
        }
    }

    private func userBubble(text: String, terminalSnapshot: String?) -> some View {
        chatMessageText(text)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(palette.elevatedSurface)
            .clipShape(Self.squircleInnerShape)
            .contextMenu {
                if let terminalSnapshot, !terminalSnapshot.isEmpty {
                    Button(String(archie: "chat.console.copy.snapshot")) {
                        copyConsoleSnapshot(terminalSnapshot)
                    }
                }
            }
    }

    private func copyConsoleSnapshot(_ snapshot: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snapshot, forType: .string)
    }

    private func chatMessageText(_ text: String) -> some View {
        Text(mentionAttributedString(text))
            .font(.system(size: 14))
            .foregroundStyle(palette.primaryText)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
    }

    private static var textEditorLineHeight: CGFloat {
        NSLayoutManager().defaultLineHeight(for: NSFont.systemFont(ofSize: 14))
    }

    private static var textEditorRowHeight: CGFloat {
        textEditorLineHeight + 2 * squircleNestedPadding
    }

    private func mentionAttributedString(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = palette.primaryText
        guard let re = try? NSRegularExpression(pattern: #"@[\w][\w.-]*"#, options: []) else {
            return result
        }
        let ns = text as NSString
        for m in re.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)).reversed() {
            guard let swiftRange = Range(m.range, in: text) else { continue }
            if let ar = Range(swiftRange, in: result) {
                result[ar].foregroundColor = palette.mentionHighlight
                result[ar].font = .system(size: 14, weight: .medium)
            }
        }
        return result
    }

    private var inputComposer: some View {
        HStack(alignment: .center, spacing: Self.squircleNestedPadding) {
            TextField(
                "",
                text: $draft,
                prompt: Text(String(archie: "chat.message.placeholder"))
                    .font(.system(size: 14))
                    .foregroundColor(palette.secondaryText)
            )
            .font(.system(size: 14))
            .foregroundColor(palette.primaryText)
            .textFieldStyle(.plain)
            .focused($inputFocused)
            .lineLimit(1)
            .onSubmit {
                if canSend { startSend() }
            }
            .padding(Self.squircleNestedPadding)
            .frame(height: Self.textEditorRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.elevatedSurface)
            .clipShape(Self.squircleInnerShape)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                startSend()
            } label: {
                Group {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(palette.onAccent)
                    } else {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.onAccent)
                    }
                }
                .frame(width: Self.textEditorRowHeight, height: Self.textEditorRowHeight)
                .background(
                    Self.squircleInnerShape
                        .fill(canSend ? palette.accent : palette.accent.opacity(0.38))
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSend)
        }
        .padding(Self.squircleNestedPadding)
        .background(
            Self.squircleOuterShape
                .fill(palette.elevatedSurface)
        )
        .overlay(
            Self.squircleOuterShape
                .strokeBorder(palette.border, lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSending
            && !sessionRegistry.isAssistantThinking(sessionID: chatSession.id)
    }

    private func cancelSend() {
        sendTask?.cancel()
    }

    @MainActor
    private func startSend() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        isSending = true
        sessionRegistry.setAssistantThinking(true, sessionID: chatSession.id)
        draft = ""

        let parts = ChatSendingPipeline.terminalSnapshotParts(from: bridge)
        do {
            try ChatSendingPipeline.appendUserMessage(
                modelContext: modelContext,
                chatSession: chatSession,
                text: text,
                terminalSnapshotUTF8: parts.stored
            )
        } catch {
            isSending = false
            sessionRegistry.setAssistantThinking(false, sessionID: chatSession.id)
            draft = text
            return
        }

        let saved = text
        let snapshotForAPI = parts.forAPI
        let epochAtSend = chatSessionEpoch
        sendTask = Task { @MainActor in
            defer {
                isSending = false
                sendTask = nil
                sessionRegistry.setAssistantThinking(false, sessionID: chatSession.id)
            }

            do {
                try Task.checkCancellation()
                try await ChatSendingPipeline.fetchAndReply(
                    modelContext: modelContext,
                    chatSession: chatSession,
                    api: api,
                    userMessageText: saved,
                    terminalContextUTF8: snapshotForAPI,
                    sessionWasInvalidated: { chatSessionEpoch != epochAtSend }
                )
            } catch {
                if ChatSendingPipeline.isCancellationLike(error) {
                    guard chatSessionEpoch == epochAtSend else { return }
                    try? ChatSendingPipeline.removeLastUserMessageIfMatches(
                        modelContext: modelContext,
                        chatSession: chatSession,
                        text: saved
                    )
                    draft = saved
                    return
                }
                try? ChatSendingPipeline.appendAssistantError(
                    modelContext: modelContext,
                    chatSession: chatSession,
                    message: String.archieChatError(detail: error.localizedDescription),
                    sessionWasInvalidated: { chatSessionEpoch != epochAtSend }
                )
            }
        }
    }
}
