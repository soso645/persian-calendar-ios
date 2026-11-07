import Foundation

/// The languages this port ships.
///
/// The Android app carries 23 locales; this port covers Persian, English and Arabic, with the
/// remaining translations left in the Android resources for a later pass.
enum AppLanguage: String, CaseIterable, Sendable {
    case fa
    case en
    case ar

    var nativeName: String {
        switch self {
        case .fa: "فارسی"
        case .en: "English"
        case .ar: "العربية"
        }
    }

    var isRTL: Bool {
        switch self {
        case .fa, .ar: true
        case .en: false
        }
    }

    var isPersianOrDari: Bool { self == .fa }
    var isUserAbleToReadPersian: Bool { self == .fa }
    var isIranExclusive: Bool { self == .fa }
    var isAfghanistanExclusive: Bool { false }
    var mightPreferUmmAlquraIslamicCalendar: Bool { self == .ar }

    var preferredNumeral: Numeral {
        switch self {
        case .fa: .persian
        case .ar: .arabicIndic
        case .en: .arabic
        }
    }

    var preferredCalendar: CalendarKind {
        switch self {
        case .fa: .shamsi
        case .ar: .islamic
        case .en: .gregorian
        }
    }

    var localeIdentifier: String {
        switch self {
        case .fa: "fa_IR"
        case .ar: "ar"
        case .en: "en_US"
        }
    }

    /// Best match for the device's preferred languages, falling back to Persian.
    static var deviceDefault: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2))
            if let language = AppLanguage(rawValue: code) { return language }
        }
        return .fa
    }
}
