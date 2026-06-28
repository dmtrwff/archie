import AppKit
import SwiftUI

struct ThemePalette: Equatable {
    var canvasBackground: Color
    var elevatedSurface: Color
    var primaryText: Color
    var secondaryText: Color
    var mentionHighlight: Color
    var border: Color
    var accent: Color
    var onAccent: Color
    var terminalForegroundNS: NSColor
    var terminalBackgroundNS: NSColor
}
