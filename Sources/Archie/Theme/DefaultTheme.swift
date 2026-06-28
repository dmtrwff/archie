import AppKit
import SwiftUI

enum DefaultTheme {
    static var palette: ThemePalette {
        ThemePalette(
            canvasBackground: Color(nsColor: .underPageBackgroundColor),
            elevatedSurface: Color(nsColor: .controlBackgroundColor),
            primaryText: Color.primary,
            secondaryText: Color.secondary,
            mentionHighlight: Color(nsColor: .controlAccentColor),
            border: Color(nsColor: .separatorColor).opacity(0.55),
            accent: Color(nsColor: .controlAccentColor),
            onAccent: Color(nsColor: .alternateSelectedControlTextColor),
            terminalForegroundNS: NSColor(calibratedWhite: 0.8, alpha: 1),
            terminalBackgroundNS: NSColor(calibratedWhite: 0.118, alpha: 1)
        )
    }
}
