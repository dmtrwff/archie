import AppKit
import Darwin
import SwiftTerm
import SwiftUI

struct TerminalHostView: NSViewRepresentable {
    @ObservedObject var session: TerminalSessionBridge
    @ObservedObject var themeManager: ThemeManager

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        context.coordinator.session = session

        let terminal: LocalProcessTerminalView
        if let existing = session.terminal {
            terminal = existing
        } else {
            let fresh = LocalProcessTerminalView(frame: .zero)
            fresh.translatesAutoresizingMaskIntoConstraints = false
            fresh.metalBufferingMode = .perFrameAggregated
            do {
                try fresh.setUseMetal(false)
            } catch {
                // Stay on the CoreText renderer by default.
            }
            fresh.getTerminal().setCursorStyle(.steadyBlock)
            fresh.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            fresh.processDelegate = context.coordinator
            session.terminal = fresh

            FileManager.default.changeCurrentDirectoryPath(
                FileManager.default.homeDirectoryForCurrentUser.path
            )
            let shell = Self.loginShellPath()
            let shellName = (shell as NSString).lastPathComponent
            fresh.startProcess(executable: shell, execName: "-" + shellName)

            terminal = fresh
        }

        terminal.translatesAutoresizingMaskIntoConstraints = false
        applyPalette(themeManager.palette, to: terminal)

        context.coordinator.terminal = terminal

        terminal.removeFromSuperview()
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            terminal.window?.makeFirstResponder(terminal)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let terminal = context.coordinator.terminal else { return }
        applyPalette(themeManager.palette, to: terminal)
    }

    private func applyPalette(_ palette: ThemePalette, to terminal: LocalProcessTerminalView) {
        terminal.nativeForegroundColor = palette.terminalForegroundNS
        terminal.nativeBackgroundColor = palette.terminalBackgroundNS
        terminal.layer?.backgroundColor = terminal.nativeBackgroundColor.cgColor
        terminal.caretColor = palette.terminalForegroundNS
        terminal.needsDisplay = true
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.terminal?.removeFromSuperview()
    }

    private static func loginShellPath() -> String {
        let bufsize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufsize > 0 else {
            return "/bin/zsh"
        }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufsize)
        defer { buffer.deallocate() }
        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        if getpwuid_r(getuid(), &pwd, buffer, bufsize, &result) != 0 || result == nil {
            return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        }
        return String(cString: pwd.pw_shell)
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        weak var terminal: LocalProcessTerminalView?
        weak var session: TerminalSessionBridge?

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Window sizing comes from SwiftUI; PTY winsize follows the view.
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            source.window?.title = title.isEmpty ? "Archie" : title
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard let directory, !directory.isEmpty else { return }
            let path: String
            if let url = URL(string: directory), url.scheme != nil {
                path = url.path
            } else {
                path = directory
            }
            source.window?.subtitle = path
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            NSApp.terminate(nil)
        }
    }
}
