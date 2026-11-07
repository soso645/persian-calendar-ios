import Foundation
import ObjectiveC

/// Makes the app's language a user setting rather than a device setting.
///
/// SwiftUI resolves `LocalizedStringKey` through `Bundle.main` using the *process's* active
/// localization. `EnvironmentValues.locale` only affects formatting (dates, numbers), so setting
/// it does not switch which `.lproj` is read — the app would stay in the device's language.
///
/// APIs like `navigationTitle`, `Section`, `Toggle` and `Button` take a `LocalizedStringKey` with
/// no bundle parameter, so routing every call site through an explicit bundle isn't possible
/// either. Instead `Bundle.main`'s class is swapped for a subclass that forwards lookups to the
/// chosen language's bundle. This is the established recipe for in-app language switching, and it
/// keeps every ordinary `Text("…")` working unchanged.
private final class LanguageForwardingBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String, value: String?, table tableName: String?
    ) -> String {
        guard let bundle = Bundle.languageOverride else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// The `.lproj` bundle the app is currently reading strings from.
    ///
    /// Written once at launch and on each language change, before the UI re-renders.
    nonisolated(unsafe) fileprivate static var languageOverride: Bundle?

    private static let installForwarding: Void = {
        object_setClass(Bundle.main, LanguageForwardingBundle.self)
    }()

    /// Point string lookups at `language`, falling back to the bundle's own default if that
    /// localization isn't present.
    static func setAppLanguage(_ language: AppLanguage) {
        _ = installForwarding
        languageOverride = Bundle.main
            .path(forResource: language.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:))
    }
}
