import XCTest
@testable import PersianCalendar

/// Mirrors `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/EventsTests.kt`.
final class EventsTests: XCTestCase {

    override func tearDown() {
        IslamicDate.useUmmAlQura = false
        super.tearDown()
    }

    /// The Kotlin version passes a `Language` and lets the repository derive this. Here the
    /// language trait is passed directly, since the language layer lands with the UI.
    func testEventsRepositorySetsIslamicDateGlobalCorrectly() {
        // Dari — prefers Umm al-Qura
        _ = EventsRepository(enabledTypes: [], mightPreferUmmAlquraIslamicCalendar: true)
        XCTAssertTrue(IslamicDate.useUmmAlQura)

        // Pashto — also prefers Umm al-Qura
        _ = EventsRepository(enabledTypes: [], mightPreferUmmAlquraIslamicCalendar: true)
        XCTAssertTrue(IslamicDate.useUmmAlQura)

        // Persian (Iran) — does not
        _ = EventsRepository(enabledTypes: [], mightPreferUmmAlquraIslamicCalendar: false)
        XCTAssertFalse(IslamicDate.useUmmAlQura)
    }

    /// Enabling Iranian events must force the Iranian tabulation regardless of language.
    func testIranianEventsForceIranianIslamicTabulation() {
        _ = EventsRepository(
            enabledTypes: [EventsRepository.iranHolidaysKey],
            mightPreferUmmAlquraIslamicCalendar: true)
        XCTAssertFalse(IslamicDate.useUmmAlQura)
    }

    func testEventsStoreHashUniquenessForDaysOfYear() {
        var hashes = Set<Int>()
        for month in 1...12 {
            for day in 1...31 {
                hashes.insert(EventsStore.hash(CivilDate(year: 2000, month: month, dayOfMonth: day)))
            }
        }
        XCTAssertEqual(372, hashes.count)
    }

    func testWorldPhilosophyDayInstances() {
        let cases = [
            (2024, 11, 21), (2025, 11, 20), (2026, 11, 19), (2027, 11, 18), (2028, 11, 16),
            (2029, 11, 15), (2030, 11, 21), (2031, 11, 20), (2032, 11, 18), (2033, 11, 17),
        ]
        let calendar = CalendarKind.gregorian
        for (year, month, day) in cases {
            XCTAssertEqual(
                day,
                calendar.getNthWeekDayOfMonth(year: year, month: month, weekDay: 5, nth: 3),
                "\(year)")
            let event = IrregularEventRecord(
                title: "روز جهانی فلسفه (سومین پنجشنبهٔ نوامبر)",
                source: .international, isHoliday: false, calendar: calendar,
                rule: .nthWeekdayOfMonth, month: 11, day: nil, year: nil, nth: 3, weekday: 5,
                offset: 0, metadata: .empty)
            let date = IrregularCalendarEventsStore.dateInstance(
                for: event, year: year, calendar: calendar)
            XCTAssertEqual(date?.year, year)
            XCTAssertEqual(date?.month, month)
            XCTAssertEqual(date?.dayOfMonth, day)
        }
    }

    func testGetNthWeekDayOfMonthCalculationsCorrectness() {
        let cases = [
            (1400, 12, 15, 1, 3), (1400, 12, 21, 7, 3), (1400, 12, 20, 6, 3),
            (1400, 12, 19, 5, 3), (1400, 12, 18, 4, 3), (1400, 12, 17, 3, 3),
            (1400, 12, 16, 2, 3),
            (1400, 12, 7, 7, 1), (1400, 12, 14, 7, 2), (1400, 12, 21, 7, 3), (1400, 12, 28, 7, 4),
            (1400, 12, 1, 1, 1), (1400, 12, 8, 1, 2), (1400, 12, 15, 1, 3), (1400, 12, 22, 1, 4),
            (1400, 12, 29, 1, 5),
            (1400, 12, 2, 2, 1), (1400, 12, 9, 2, 2), (1400, 12, 16, 2, 3), (1400, 12, 23, 2, 4),
            (1400, 12, 3, 3, 1), (1400, 12, 10, 3, 2), (1400, 12, 17, 3, 3), (1400, 12, 24, 3, 4),
            (1400, 12, 4, 4, 1), (1400, 12, 11, 4, 2), (1400, 12, 18, 4, 3), (1400, 12, 25, 4, 4),
            (1400, 12, 5, 5, 1), (1400, 12, 12, 5, 2), (1400, 12, 19, 5, 3), (1400, 12, 26, 5, 4),
            (1400, 12, 6, 6, 1), (1400, 12, 13, 6, 2), (1400, 12, 20, 6, 3), (1400, 12, 27, 6, 4),
        ]
        let calendar = CalendarKind.shamsi
        for (year, month, day, weekDay, nth) in cases {
            let label = "\(year)/\(month) weekday \(weekDay) nth \(nth)"
            XCTAssertEqual(
                day,
                calendar.getNthWeekDayOfMonth(
                    year: year, month: month, weekDay: weekDay, nth: nth),
                label)
            let event = IrregularEventRecord(
                title: "", source: .iran, isHoliday: false, calendar: calendar,
                rule: .nthWeekdayOfMonth, month: month, day: nil, year: nil, nth: nth,
                weekday: weekDay, offset: 0, metadata: .empty)
            let date = IrregularCalendarEventsStore.dateInstance(
                for: event, year: year, calendar: calendar)
            XCTAssertEqual(date?.year, year, label)
            XCTAssertEqual(date?.month, month, label)
            XCTAssertEqual(date?.dayOfMonth, day, label)
        }
    }

    func testGetLastWeekDayOfMonthCalculationsCorrectness() {
        let cases = [
            (1400, 12, 29, 1), (1400, 12, 28, 7), (1400, 12, 27, 6), (1400, 12, 26, 5),
            (1400, 12, 25, 4), (1400, 12, 24, 3), (1400, 12, 23, 2),
            (1399, 12, 29, 6), (1398, 12, 23, 6), (1397, 12, 24, 6), (1396, 12, 25, 6),
            (1395, 12, 27, 6), (1394, 12, 28, 6), (1393, 12, 29, 6), (1392, 12, 23, 6),
            (1391, 12, 25, 6), (1390, 12, 26, 6),
        ]
        let calendar = CalendarKind.shamsi
        for (year, month, day, weekDay) in cases {
            let label = "\(year)/\(month) weekday \(weekDay)"
            XCTAssertEqual(
                day,
                calendar.getLastWeekDayOfMonth(year: year, month: month, weekDay: weekDay),
                label)
            let event = IrregularEventRecord(
                title: "", source: .iran, isHoliday: false, calendar: calendar,
                rule: .lastWeekdayOfMonth, month: month, day: nil, year: nil, nth: nil,
                weekday: weekDay, offset: 0, metadata: .empty)
            let date = IrregularCalendarEventsStore.dateInstance(
                for: event, year: year, calendar: calendar)
            XCTAssertEqual(date?.year, year, label)
            XCTAssertEqual(date?.month, month, label)
            XCTAssertEqual(date?.dayOfMonth, day, label)
        }
    }

    // MARK: - Data loading

    func testEventsJsonLoadsWithExpectedShape() {
        let data = EventsData.shared
        let simpleCount = data.persianEvents.count + data.islamicEvents.count
            + data.gregorianEvents.count + data.nepaliEvents.count
        // 641 rows in events.json: 627 simple, 14 irregular.
        XCTAssertEqual(simpleCount, 627)
        XCTAssertEqual(data.irregularRecurringEvents.count, 14)
        // Per calendar: Persian 395 simple / 7 irregular, Hijri 91 / 3, Gregorian 141 / 4.
        XCTAssertEqual(data.persianEvents.count, 395)
        XCTAssertEqual(data.islamicEvents.count, 91)
        XCTAssertEqual(data.gregorianEvents.count, 141)
        XCTAssertEqual(data.nepaliEvents.count, 0)
        XCTAssertEqual(data.sourceLinks.count, 6)
    }

    func testNowruzIsAHolidayWhenIranianHolidaysAreEnabled() {
        let repository = EventsRepository(enabledTypes: [EventsRepository.iranHolidaysKey])
        let nowruz = Jdn(.shamsi, 1403, 1, 1)
        let events = repository.events(for: nowruz)
        XCTAssertTrue(events.contains { $0.isHoliday }, "Nowruz must be a holiday")
        XCTAssertTrue(
            events.contains { $0.metadata.originalTitle?.contains("نوروز") == true },
            "Nowruz must be present, got: \(events.map(\.title))")
    }

    func testNoEventsWhenNothingIsEnabled() {
        let repository = EventsRepository(enabledTypes: [])
        XCTAssertTrue(repository.isEmpty)
        let events = repository.events(for: Jdn(.shamsi, 1403, 1, 1))
        XCTAssertTrue(events.isEmpty, "got: \(events.map(\.title))")
    }
}
