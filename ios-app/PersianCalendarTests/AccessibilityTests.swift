import XCTest
@testable import PersianCalendar

/// The month grid is the app's densest screen and the one VoiceOver handles worst by default —
/// without a label it reads the bare digits and the decorative marks. These check the spoken
/// description is built correctly.
@MainActor
final class AccessibilityTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "a11y-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        IslamicDate.useUmmAlQura = false
        IslamicDate.islamicOffset = 0
        super.tearDown()
    }

    private func grid(language: AppLanguage = .fa) -> MonthGrid {
        let settings = AppSettings(defaults: defaults)
        settings.language = language
        settings.mainCalendar = .shamsi
        settings.holidayTypes = [EventsRepository.iranHolidaysKey]
        // Nowruz, so the month has both a holiday and named events in it.
        let today = Jdn(.shamsi, 1403, 1, 1)
        return MonthGrid.build(
            offset: 0, today: today, settings: MonthGrid.Snapshot(settings))
    }

    /// Every real day gets a label; padding cells get none so VoiceOver skips them.
    func testEveryDayCellHasALabelAndPaddingHasNone() {
        let grid = self.grid()
        for cell in grid.cells {
            if cell.jdn == nil {
                XCTAssertNil(cell.accessibilityLabel, "padding cell should not be spoken")
            } else {
                let label = cell.accessibilityLabel
                XCTAssertNotNil(label, "day \(cell.dayOfMonth ?? -1) has no label")
                XCTAssertFalse(label!.isEmpty)
            }
        }
    }

    /// The label leads with the weekday and full date rather than a bare number.
    func testLabelStartsWithWeekdayAndDate() {
        let grid = self.grid()
        let first = grid.cells.first { $0.dayOfMonth == 1 }
        let label = try? XCTUnwrap(first?.accessibilityLabel)
        // 1 Farvardin 1403 was a Wednesday.
        XCTAssertTrue(
            label?.hasPrefix("چهارشنبه") == true,
            "expected the weekday first, got: \(label ?? "nil")")
        XCTAssertTrue(
            label?.contains("فروردین") == true,
            "expected the month name, got: \(label ?? "nil")")
    }

    /// Holidays and events are announced, since colour and dots convey them visually.
    func testHolidaysAndEventsAreSpoken() {
        let grid = self.grid()
        let nowruz = try? XCTUnwrap(grid.cells.first { $0.dayOfMonth == 1 })
        let label = nowruz?.accessibilityLabel ?? ""
        XCTAssertTrue(label.contains("تعطیل"), "holiday not announced: \(label)")
        XCTAssertTrue(label.contains("نوروز"), "event not announced: \(label)")
    }

    /// The word for "holiday" follows the app language.
    func testHolidayWordIsLocalized() {
        for (language, word) in [(AppLanguage.fa, "تعطیل"), (.ar, "عطلة"), (.en, "holiday")] {
            let grid = self.grid(language: language)
            let holiday = grid.cells.first {
                $0.isHoliday && $0.accessibilityLabel != nil
            }
            let label = holiday?.accessibilityLabel ?? ""
            XCTAssertTrue(
                label.contains(word),
                "\(language.rawValue) label should contain '\(word)', got: \(label)")
        }
    }

    /// A label built for a day with several events must mention each of them.
    func testAllEventsOnADayAreIncluded() {
        let settings = AppSettings(defaults: defaults)
        settings.language = .fa
        settings.mainCalendar = .shamsi
        settings.holidayTypes = [
            EventsRepository.iranHolidaysKey, EventsRepository.iranOthersKey,
        ]
        let today = Jdn(.shamsi, 1403, 1, 1)
        let grid = MonthGrid.build(
            offset: 0, today: today, settings: MonthGrid.Snapshot(settings))

        for cell in grid.cells {
            guard let jdn = cell.jdn, let label = cell.accessibilityLabel else { continue }
            for event in settings.eventsRepository.events(for: jdn) {
                XCTAssertTrue(
                    label.contains(event.title),
                    "label for \(cell.dayOfMonth ?? -1) omits '\(event.title)'")
            }
        }
    }
}
