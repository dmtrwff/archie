import SwiftData
import SwiftUI

private enum AppModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ChatPersistence.makeModelContainer()
        } catch {
            do {
                return try ChatPersistence.inMemoryFallbackContainer()
            } catch {
                fatalError("SwiftData: \(error)")
            }
        }
    }()
}

@main
struct ArchieApp: App {
    @StateObject private var chatRouter = ChatRouter()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var sessionRegistry = SessionWorkspaceRegistry()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatRouter)
                .environmentObject(themeManager)
                .environmentObject(sessionRegistry)
                .modelContainer(AppModelContainer.shared)
                .frame(
                    minWidth: ContentView.minimumWindowWidth,
                    minHeight: ContentView.minimumWindowHeight
                )
        }
        .defaultSize(width: 1100, height: 600)
        .windowResizability(.contentMinSize)

        Settings {
            OpenAISettingsView()
                .environmentObject(chatRouter)
                .environmentObject(themeManager)
        }
    }
}

struct ContentView: View {
    private static let draftSessionName = String(archie: "session.draft.displayName")
    private static let sidebarMinWidth: CGFloat = 180
    private static let sidebarIdealWidth: CGFloat = 230
    private static let sidebarMaxWidth: CGFloat = 320
    private static let terminalMinWidth: CGFloat = 280
    /// Horizontal padding on the terminal column (`padding(.horizontal, 10)` each side).
    private static let terminalHorizontalPaddingTotal: CGFloat = 20
    private static let terminalIdealWidth: CGFloat = 680
    private static let chatMinWidth: CGFloat = 240
    private static let chatIdealWidth: CGFloat = 340
    private static let chatMaxWidth: CGFloat = 460
    /// Allowance for `HSplitView` dividers, `NavigationSplitView` chrome, and window margins.
    private static let splitAndWindowChromeAllowance: CGFloat = 180

    /// Width must cover column mins plus chrome or the three-column layout clips content.
    static let minimumWindowWidth: CGFloat =
        sidebarMinWidth
            + terminalMinWidth
            + terminalHorizontalPaddingTotal
            + chatMinWidth
            + splitAndWindowChromeAllowance

    static let minimumWindowHeight: CGFloat = 420

    @EnvironmentObject private var chatRouter: ChatRouter
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var sessionRegistry: SessionWorkspaceRegistry
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSessionRecord.createdAt, order: .forward)
    private var persistedSessionsStorage: [ChatSessionRecord]

    private var persistedSessions: [ChatSessionRecord] {
        persistedSessionsStorage.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.createdAt > b.createdAt
        }
    }

    @State private var selectedSession: ChatSessionRecord?

    var body: some View {
        NavigationSplitView {
            SessionSidebarView(
                selectedSession: $selectedSession,
                sessionRegistry: sessionRegistry,
                onCreateSession: createNewDraftSession,
                onDeleteSession: deleteSession
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationSplitViewColumnWidth(
                min: Self.sidebarMinWidth,
                ideal: Self.sidebarIdealWidth,
                max: Self.sidebarMaxWidth
            )
        } detail: {
            Group {
                if let session = selectedSession {
                    HSplitView {
                        ZStack(alignment: .bottomTrailing) {
                            TerminalHostView(session: sessionRegistry.bridge(for: session), themeManager: themeManager)
                                .frame(minWidth: Self.terminalMinWidth, idealWidth: Self.terminalIdealWidth, maxWidth: .infinity)
                                .layoutPriority(1)

                            Button {
                                sendTerminalContextToAssistant(session: session)
                            } label: {
                                Text(String(archie: "terminal.show_to_ai.button"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(themeManager.palette.onAccent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(themeManager.palette.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(sessionRegistry.isAssistantThinking(sessionID: session.id))
                            .help(String(archie: "terminal.show_to_ai.help"))
                            .padding(.trailing, 52)
                            .padding(.bottom, 10)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .id(session.id)
                        ChatSidePanel(
                            chatSession: session,
                            bridge: sessionRegistry.bridge(for: session),
                            api: chatRouter,
                            sessionRegistry: sessionRegistry,
                            onDeleteSession: { deleteSession(session) }
                        )
                        .frame(minWidth: Self.chatMinWidth, idealWidth: Self.chatIdealWidth, maxWidth: Self.chatMaxWidth)
                        .id(session.id)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        String(archie: "session.empty.title"),
                        systemImage: "rectangle.split.2x1",
                        description: Text(String(archie: "session.empty.description"))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(themeManager.palette.canvasBackground)
        }
        .background(themeManager.palette.canvasBackground)
        .preferredChromeColorScheme(for: themeManager.theme)
        .ignoresSafeArea(edges: .bottom)
        .task {
            try? ChatPersistence.bootstrapIfNeeded(modelContext: modelContext)
            if selectedSession == nil {
                selectedSession = persistedSessions.first ?? makeDraftSession()
            }
        }
    }

    private func makeDraftSession() -> ChatSessionRecord {
        ChatSessionRecord(name: Self.draftSessionName)
    }

    private func createNewDraftSession() {
        selectedSession = makeDraftSession()
    }

    private func deleteSession(_ session: ChatSessionRecord) {
        sessionRegistry.releaseBridge(sessionID: session.id)
        if persistedSessions.contains(where: { $0.id == session.id }) {
            modelContext.delete(session)
            try? modelContext.save()
        }
        selectedSession = makeDraftSession()
    }

    private func sendTerminalContextToAssistant(session: ChatSessionRecord) {
        let bridge = sessionRegistry.bridge(for: session)
        let sid = session.id
        sessionRegistry.setAssistantThinking(true, sessionID: sid)
        Task { @MainActor in
            defer { sessionRegistry.setAssistantThinking(false, sessionID: sid) }
            do {
                try await ChatSendingPipeline.sendTurnWithCapturedTerminal(
                    modelContext: modelContext,
                    chatSession: session,
                    api: chatRouter,
                    bridge: bridge,
                    userText: String(archie: "terminal.show_to_ai.context_message"),
                    sessionWasInvalidated: { selectedSession?.id != sid }
                )
            } catch {
                if error is CancellationError { return }
                if let url = error as? URLError, url.code == .cancelled { return }
                guard selectedSession?.id == sid else { return }
                try? ChatSendingPipeline.appendAssistantError(
                    modelContext: modelContext,
                    chatSession: session,
                    message: String.archieChatError(detail: error.localizedDescription),
                    sessionWasInvalidated: { selectedSession?.id != sid }
                )
            }
        }
    }
}
