import AppKit
import SwiftUI

enum MatrixTheme {
    /// Classic “matrix green” ~ #00FF41
    static let phosphor = Color(red: 0, green: 1, blue: 65 / 255)
    /// Secondary copy / hints
    static let phosphorDim = Color(red: 0, green: 0.55, blue: 0.24)
    /// Highlight for @mentions
    static let phosphorBright = Color(red: 0.15, green: 1, blue: 0.35)

    static let void = Color(red: 0.02, green: 0.04, blue: 0.03)
    static let surface = Color(red: 0.06, green: 0.14, blue: 0.09)
    static let surfaceElevated = Color(red: 0.09, green: 0.2, blue: 0.12)

    static let border = Color(red: 0, green: 0.45, blue: 0.22).opacity(0.55)

    /// Text/icons on bright accent buttons
    static let onPhosphor = Color(red: 0.02, green: 0.06, blue: 0.04)

    static let terminalForegroundNS = NSColor(srgbRed: 0, green: 1, blue: 65 / 255, alpha: 1)
    static let terminalBackgroundNS = NSColor(srgbRed: 0.02, green: 0.04, blue: 0.03, alpha: 1)

    static var palette: ThemePalette {
        ThemePalette(
            canvasBackground: void,
            elevatedSurface: surfaceElevated,
            primaryText: phosphor,
            secondaryText: phosphorDim,
            mentionHighlight: phosphorBright,
            border: border,
            accent: phosphor,
            onAccent: onPhosphor,
            terminalForegroundNS: terminalForegroundNS,
            terminalBackgroundNS: terminalBackgroundNS
        )
    }
}
