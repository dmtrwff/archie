import SwiftUI

/// Built-in themes (`DefaultTheme`, `MatrixTheme`). The selection id is stored in `UserDefaults.shared`.
enum VisualAppearanceTheme: String, CaseIterable, Identifiable {
    case standard
    case matrix

    var id: String { persistenceKey }

    /// Persistence key for stored appearance (`UserDefaults.Keys.appearanceThemeID`).
    var persistenceKey: String {
        switch self {
        case .standard: return "default"
        case .matrix: return "matrix"
        }
    }

    var title: String {
        switch self {
        case .standard: return String(archie: "appearance.theme.standard")
        case .matrix: return String(archie: "appearance.theme.matrix")
        }
    }

    var previewSystemImage: String {
        switch self {
        case .standard: return "circle.lefthalf.filled"
        case .matrix: return "leaf.fill"
        }
    }

    var prefersDarkChrome: Bool {
        self != .standard
    }

    var palette: ThemePalette {
        switch self {
        case .standard: return DefaultTheme.palette
        case .matrix: return MatrixTheme.palette
        }
    }

    static func theme(id: String?) -> VisualAppearanceTheme {
        guard let id, !id.isEmpty else { return .matrix }
        switch id {
        case "default", "standard":
            return .standard
        case "matrix":
            return .matrix
        default:
            return .matrix
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published var theme: VisualAppearanceTheme {
        didSet {
            guard theme != oldValue else { return }
            UserDefaults.shared.appearanceTheme = theme
        }
    }

    init() {
        theme = UserDefaults.shared.appearanceTheme
    }

    var palette: ThemePalette {
        theme.palette
    }
}

extension View {
    @ViewBuilder
    func preferredChromeColorScheme(for theme: VisualAppearanceTheme) -> some View {
        if theme.prefersDarkChrome {
            preferredColorScheme(.dark)
        } else {
            self
        }
    }
}
