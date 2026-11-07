import XCTest
@testable import PersianCalendar

/// Guards against the localization traps this port has already hit once each:
/// missing catalog keys, and names that only exist in English.
final class LocalizationTests: XCTestCase {

    private func bundle(for language: AppLanguage) throws -> Bundle {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            "no \(language.rawValue).lproj in the bundle")
        return try XCTUnwrap(Bundle(path: path))
    }

    /// Every shipped language must have a compiled strings table.
    func testAllLanguagesHaveACompiledCatalog() throws {
        for language in AppLanguage.allCases {
            let bundle = try bundle(for: language)
            let value = bundle.localizedString(forKey: "Settings", value: "@@missing", table: nil)
            XCTAssertNotEqual(value, "@@missing", "\(language.rawValue) has no Settings key")
        }
    }

    /// A sample of keys from every screen, so a missing translation fails here rather than
    /// silently rendering English inside a Persian UI.
    func testKeyUserFacingStringsAreTranslated() throws {
        let keys = [
            "Today", "Events", "Times", "Settings", "About", "Converter", "Compass", "Level",
            "Astronomy", "Week", "Year", "Language", "Main calendar", "Location",
            "Prayer times", "Shift work", "Hijri offset", "Age", "Illumination", "Moon", "Sun",
            "No events", "Go to date", "Previous", "Next",
        ]
        for language in AppLanguage.allCases where language != .en {
            let bundle = try bundle(for: language)
            let english = try self.bundle(for: .en)
            for key in keys {
                let translated = bundle.localizedString(
                    forKey: key, value: "@@missing", table: nil)
                XCTAssertNotEqual(
                    translated, "@@missing", "\(language.rawValue) is missing '\(key)'")
                let englishValue = english.localizedString(forKey: key, value: key, table: nil)
                XCTAssertNotEqual(
                    translated, englishValue,
                    "\(language.rawValue) left '\(key)' untranslated")
            }
        }
    }

    /// Zodiac, Chinese zodiac and calendar names come from Swift, not the catalog, so they need
    /// their own check that no language falls back to the English case name.
    func testDataDrivenNamesAreLocalized() {
        for language in AppLanguage.allCases {
            for zodiac in Zodiac.allCases {
                let title = zodiac.localizedTitle(language)
                XCTAssertFalse(title.isEmpty, "\(zodiac) empty in \(language.rawValue)")
                if language != .en {
                    XCTAssertNotEqual(
                        title, "\(zodiac)".capitalized,
                        "\(zodiac) fell back to English in \(language.rawValue)")
                }
            }
            for animal in ChineseZodiac.allCases {
                XCTAssertFalse(
                    animal.localizedTitle(language).isEmpty,
                    "\(animal) empty in \(language.rawValue)")
            }
            for calendar in CalendarKind.allCases {
                XCTAssertFalse(
                    calendar.localizedTitle(language).isEmpty,
                    "\(calendar) empty in \(language.rawValue)")
            }
            for kind in PrayTimeKind.allCases {
                XCTAssertFalse(
                    kind.localizedTitle(language).isEmpty,
                    "\(kind) empty in \(language.rawValue)")
            }
        }
    }

    /// Month and weekday names must be complete for every calendar and language.
    func testCalendarNamesAreComplete() {
        for language in AppLanguage.allCases {
            XCTAssertEqual(CalendarNames.weekDays(language).count, 7)
            XCTAssertEqual(CalendarNames.weekDaysInitials(language).count, 7)
            for calendar in CalendarKind.allCases {
                let months = CalendarNames.months(for: calendar, language: language)
                XCTAssertEqual(
                    months.count, 12, "\(calendar) in \(language.rawValue)")
                XCTAssertTrue(
                    months.allSatisfy { !$0.isEmpty },
                    "\(calendar) has a blank month name in \(language.rawValue)")
                // A Latin letter inside a Persian or Arabic name means a half-finished
                // transliteration slipped through.
                if language != .en {
                    for month in months {
                        XCTAssertNil(
                            month.rangeOfCharacter(from: CharacterSet(charactersIn: "a"..."z")),
                            "\(calendar) month '\(month)' has Latin text in \(language.rawValue)")
                    }
                }
            }
        }
    }

    /// Persian and Arabic are right-to-left; English is not.
    func testTextDirection() {
        XCTAssertTrue(AppLanguage.fa.isRTL)
        XCTAssertTrue(AppLanguage.ar.isRTL)
        XCTAssertFalse(AppLanguage.en.isRTL)
    }
}
