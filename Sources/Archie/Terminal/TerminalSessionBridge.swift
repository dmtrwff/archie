import Combine
import SwiftTerm

@MainActor
final class TerminalSessionBridge: ObservableObject {
    /// Owned strongly so the shell keeps running when another sidebar session is selected.
    var terminal: LocalProcessTerminalView?

    func consoleSnapshotUTF8() -> String {
        guard let terminal else { return "" }
        let data = terminal.getTerminal().getBufferAsData()
        return String(decoding: data, as: UTF8.self)
    }

    func runShellInput(_ command: String) {
        guard let terminal else { return }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let payload = trimmed.hasSuffix("\n") ? trimmed : trimmed + "\n"
        terminal.send(txt: payload)
    }

    func terminateTerminal() {
        terminal?.terminate()
        terminal = nil
    }
}
