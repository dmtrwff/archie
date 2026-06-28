import Foundation

extension Bundle {
    /// Hosts `Resources/Localizable.xcstrings` (SPM: `Bundle.module`, Xcode app: `Bundle.main`).
    static var archieLocalized: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }
}

extension String {
    /// Resolved via the Archie string catalog (`Localizable`).
    init(archie key: String.LocalizationValue) {
        self.init(localized: key, table: "Localizable", bundle: .archieLocalized)
    }

    static func archieChatError(detail: String) -> String {
        String(format: String(archie: "chat.error.format"), detail)
    }

    static func archieKeychainError(code: Int32) -> String {
        String(format: String(archie: "errors.keychain.status"), code)
    }
}
