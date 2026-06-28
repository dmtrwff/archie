import Foundation

enum UTF8Truncation {
    /// UTF-8–safe tail preservation; prepends `banner` when bytes exceed `maxUTF8Bytes`.
    static func cappedTailWithBanner(_ raw: String, maxUTF8Bytes: Int, banner: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let bytes = Array(trimmed.utf8)
        guard bytes.count > maxUTF8Bytes else { return trimmed }
        let dropCount = bytes.count - maxUTF8Bytes
        var start = dropCount
        while start < bytes.count && (bytes[start] & 0xC0) == 0x80 {
            start += 1
        }
        let suffix = String(decoding: bytes[start...], as: UTF8.self)
        return banner + "\n\n" + suffix
    }
}

enum TerminalSnapshotStorage {
    /// Keeps SwiftData rows bounded when scrollback is huge (recent tail is kept).
    static let maxUTF8Bytes = 512_000

    /// Returns trimmed + capped UTF-8 text, or nil when empty after trim.
    static func prepare(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UTF8Truncation.cappedTailWithBanner(
            trimmed,
            maxUTF8Bytes: maxUTF8Bytes,
            banner: String(archie: "terminal.snapshot.truncation.banner")
        )
    }
}
