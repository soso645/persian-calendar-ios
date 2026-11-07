import SwiftUI

/// The prayer and solar times the app displays, in the order they occur.
///
/// The Kotlin original is `entities/PrayTime.kt`. The raw values are persisted in the athan alarm
/// preference, so don't change them.
enum PrayTimeKind: String, CaseIterable, Identifiable, Sendable {
    case imsak = "IMSAK"
    case fajr = "FAJR"
    case sunrise = "SUNRISE"
    case dhuhr = "DHUHR"
    case asr = "ASR"
    case sunset = "SUNSET"
    case maghrib = "MAGHRIB"
    case isha = "ISHA"
    case midnight = "MIDNIGHT"

    var id: String { rawValue }

    func value(from times: PrayTimes) -> Double {
        switch self {
        case .imsak: times.imsak
        case .fajr: times.fajr
        case .sunrise: times.sunrise
        case .dhuhr: times.dhuhr
        case .asr: times.asr
        case .sunset: times.sunset
        case .maghrib: times.maghrib
        case .isha: times.isha
        case .midnight: times.midnight
        }
    }

    var tint: Color {
        switch self {
        case .fajr: Color(red: 0.0, green: 0.59, blue: 0.53)
        case .dhuhr: Color(red: 0.945, green: 0.643, blue: 0.165)
        case .asr: Color(red: 0.961, green: 0.486, blue: 0.004)
        case .maghrib: Color(red: 0.369, green: 0.208, blue: 0.694)
        case .isha: Color(red: 0.157, green: 0.208, blue: 0.576)
        default: .gray
        }
    }

    /// Used in the day view; the two midday times get a bright icon.
    var systemImage: String {
        switch self {
        case .dhuhr, .asr: "sun.max.fill"
        default: "moon.fill"
        }
    }

    /// Whether the time is shown even when the user hasn't enabled every entry.
    func isAlwaysShown(isJafari: Bool) -> Bool {
        switch self {
        case .fajr, .dhuhr, .maghrib: true
        case .asr, .isha: !isJafari
        default: false
        }
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.imsak, .fa): "امساک"
        case (.imsak, .ar): "الإمساك"
        case (.imsak, .en): "Imsak"
        case (.fajr, .fa): "صبح"
        case (.fajr, .ar): "الفجر"
        case (.fajr, .en): "Fajr"
        case (.sunrise, .fa): "طلوع"
        case (.sunrise, .ar): "الشروق"
        case (.sunrise, .en): "Sunrise"
        case (.dhuhr, .fa): "ظهر"
        case (.dhuhr, .ar): "الظهر"
        case (.dhuhr, .en): "Dhuhr"
        case (.asr, .fa): "عصر"
        case (.asr, .ar): "العصر"
        case (.asr, .en): "Asr"
        case (.sunset, .fa): "غروب"
        case (.sunset, .ar): "الغروب"
        case (.sunset, .en): "Sunset"
        case (.maghrib, .fa): "مغرب"
        case (.maghrib, .ar): "المغرب"
        case (.maghrib, .en): "Maghrib"
        case (.isha, .fa): "عشاء"
        case (.isha, .ar): "العشاء"
        case (.isha, .en): "Isha"
        case (.midnight, .fa): "نیمه‌شب"
        case (.midnight, .ar): "منتصف الليل"
        case (.midnight, .en): "Midnight"
        }
    }
}
