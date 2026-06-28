import SwiftData
import SwiftUI

struct SessionSidebarView: View {
    @Binding var selectedSession: ChatSessionRecord?
    @ObservedObject var sessionRegistry: SessionWorkspaceRegistry
    var onCreateSession: () -> Void
    var onDeleteSession: (ChatSessionRecord) -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    @Query(sort: \ChatSessionRecord.createdAt, order: .forward)
    private var sessionsStorage: [ChatSessionRecord]

    private var sessions: [ChatSessionRecord] {
        sessionsStorage.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.createdAt > b.createdAt
        }
    }

    private var sessionsAnimationSignature: String {
        sessions.map { session in
            "\(session.id.uuidString)|\(session.isPinned)|\(session.createdAt.timeIntervalSinceReferenceDate)"
        }.joined(separator: ";")
    }

    private var palette: ThemePalette { themeManager.palette }

    private static let squircleInnerCornerRadius: CGFloat = 16
    private static var squircleInnerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: squircleInnerCornerRadius, style: .continuous)
    }

    private static let headerNavBubbleHeight: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let selectedSession, sessions.contains(where: { $0.id == selectedSession.id }) == false {
                        SessionSidebarRow(
                            session: selectedSession,
                            sessionRegistry: sessionRegistry,
                            isSelected: true,
                            palette: palette,
                            squircleShape: Self.squircleInnerShape
                        )
                            .contentShape(Rectangle())
                    }

                    ForEach(sessions) { session in
                        SessionSidebarRow(
                            session: session,
                            sessionRegistry: sessionRegistry,
                            isSelected: selectedSession?.id == session.id,
                            palette: palette,
                            squircleShape: Self.squircleInnerShape
                        )
                        .contentShape(Rectangle())
                        .transition(.opacity)
                        .onTapGesture {
                            selectedSession = session
                        }
                        .contextMenu {
                            Button(String(archie: "session.delete"), role: .destructive) {
                                onDeleteSession(session)
                            }
                        }
                    }
                }
                    .animation(.easeInOut(duration: 0.25), value: sessionsAnimationSignature)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
            .background(palette.canvasBackground)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.canvasBackground)
    }

    private var headerBar: some View {
        Button {
            onCreateSession()
        } label: {
            HStack(spacing: 10) {
                Text(String(archie: "session.sidebar.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer(minLength: 12)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(3)
                    .background(.clear)
                    .clipShape(Circle())
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
            .buttonStyle(.plain)
            .help(String(archie: "session.new.help"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

}

private struct SessionSidebarRow: View {
    let session: ChatSessionRecord
    @ObservedObject var sessionRegistry: SessionWorkspaceRegistry
    var isSelected: Bool
    var palette: ThemePalette
    var squircleShape: RoundedRectangle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if session.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }
            Text(session.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if sessionRegistry.isAssistantThinking(sessionID: session.id) {
                ProgressView()
                    .controlSize(.small)
                    .tint(palette.accent)
            }
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(palette.elevatedSurface)
            .clipShape(squircleShape)
            .overlay(
            squircleShape.strokeBorder(
                isSelected ? palette.accent : palette.border,
                lineWidth: isSelected ? 2 : 1
            )
        )
    }
}
