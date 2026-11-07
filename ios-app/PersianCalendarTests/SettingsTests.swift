import XCTest
@testable import PersianCalendar

/// Phase 3 coverage: settings round-trip through UserDefaults, shift-work rota resolution, and the
/// bundled city list. No Android counterpart — the Kotlin settings live in Compose globals that
/// aren't unit tested.
@MainActor
final class SettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        IslamicDate.islamicOffset = 0
        IslamicDate.useUmmAlQura = false
        super.tearDown()
    }

    func testDefaultsApplyWhenNothingIsStored() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.localNumeral)
        XCTAssertTrue(settings.redHolidays)
        XCTAssertFalse(settings.iranTime)
        XCTAssertFalse(settings.secondaryCalendarInTable)
        XCTAssertEqual(settings.prayTimeMethod, .Tehran)
        XCTAssertEqual(settings.highLatitudesMethod, .nightMiddle)
        XCTAssertEqual(settings.hijriOffset, 0)
        XCTAssertEqual(settings.weekStart, .saturday)
        XCTAssertEqual(settings.weekEnds, [.friday])
        XCTAssertNil(settings.coordinates)
    }

    func testSettingsPersistAndReload() {
        let settings = AppSettings(defaults: defaults)
        settings.language = .en
        settings.mainCalendar = .gregorian
        settings.otherCalendars = [.shamsi, .nepali]
        settings.iranTime = true
        settings.localNumeral = false
        settings.hijriOffset = -1
        settings.prayTimeMethod = .MWL
        settings.weekStart = .monday
        settings.weekEnds = [.saturday, .sunday]
        settings.coordinates = Coordinates(
            latitude: 35.6892, longitude: 51.3890, elevation: 1200)
        settings.holidayTypes = [EventsRepository.iranHolidaysKey]

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.language, .en)
        XCTAssertEqual(reloaded.mainCalendar, .gregorian)
        XCTAssertEqual(reloaded.otherCalendars, [.shamsi, .nepali])
        XCTAssertTrue(reloaded.iranTime)
        XCTAssertFalse(reloaded.localNumeral)
        XCTAssertEqual(reloaded.hijriOffset, -1)
        XCTAssertEqual(reloaded.prayTimeMethod, .MWL)
        XCTAssertEqual(reloaded.weekStart, .monday)
        XCTAssertEqual(reloaded.weekEnds, [.saturday, .sunday])
        XCTAssertEqual(reloaded.coordinates?.latitude ?? 0, 35.6892, accuracy: 1e-9)
        XCTAssertEqual(reloaded.coordinates?.elevation ?? 0, 1200, accuracy: 1e-9)
        XCTAssertEqual(reloaded.holidayTypes, [EventsRepository.iranHolidaysKey])
    }

    /// The offset shifts which Hijri date a given day maps to, which is how users reconcile the
    /// app with a locally announced moon sighting.
    func testHijriOffsetReachesTheIslamicCalendar() {
        let settings = AppSettings(defaults: defaults)
        let day = Jdn(.shamsi, 1403, 1, 1)

        XCTAssertEqual(settings.hijriOffset, 0)
        let nextDayUnshifted = IslamicDate(jdn: day.value + 1)

        settings.hijriOffset = 1
        let shifted = IslamicDate(jdn: day.value)

        // With a +1 offset, today shows the Hijri date that tomorrow would otherwise have.
        XCTAssertEqual(shifted, nextDayUnshifted, "offset did not reach the converter")
    }

    func testNumeralFollowsLanguageAndToggle() {
        let settings = AppSettings(defaults: defaults)
        settings.language = .fa
        XCTAssertEqual(settings.numeral, .persian)
        settings.language = .en
        XCTAssertEqual(settings.numeral, .arabic)
        settings.language = .ar
        XCTAssertEqual(settings.numeral, .arabicIndic)
        settings.localNumeral = false
        XCTAssertEqual(settings.numeral, .arabic)
    }

    func testPrayTimesUseTheStoredLocation() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertNil(settings.prayTimes(for: Jdn(.shamsi, 1403, 1, 1)))
        settings.coordinates = Coordinates(
            latitude: 35.6892, longitude: 51.3890, elevation: 1200)
        // Pin the zone to Tehran's; with the device's zone the times are still correct but wrap
        // past midnight, since they are expressed in the viewer's local clock.
        let tehranZone = TimeZone(identifier: "Asia/Tehran")!
        let times = settings.prayTimes(for: Jdn(.shamsi, 1403, 1, 1), timeZone: tehranZone)
        XCTAssertNotNil(times)
        guard let times else { return }
        XCTAssertLessThan(times.fajr, times.sunrise)
        XCTAssertLessThan(times.sunrise, times.dhuhr)
        XCTAssertLessThan(times.dhuhr, times.asr)
        XCTAssertLessThan(times.asr, times.sunset)
        // Nowruz is the equinox, so sunrise is close to 06:00 and dhuhr close to noon.
        XCTAssertEqual(times.sunrise, 6.2, accuracy: 0.5)
        XCTAssertEqual(times.dhuhr, 12.2, accuracy: 0.5)
    }

    // MARK: - Shift work

    func testShiftWorkRotaResolvesEachDay() {
        let start = Jdn(.shamsi, 1403, 1, 1)
        let rota = ShiftWorkSettings(
            recurs: true,
            startingJdn: start,
            records: [
                ShiftWorkRecord(type: "d", length: 2),
                ShiftWorkRecord(type: "n", length: 2),
                ShiftWorkRecord(type: "r", length: 1),
            ])

        let expected = ["d", "d", "n", "n", "r", "d", "d", "n", "n", "r"]
        for (offset, type) in expected.enumerated() {
            XCTAssertEqual(rota.workTitle(for: start + offset), type, "day \(offset)")
        }
        // Before the start date the rota doesn't apply.
        XCTAssertNil(rota.workTitle(for: start - 1))
    }

    func testNonRecurringShiftWorkStopsAfterOnePeriod() {
        let start = Jdn(.shamsi, 1403, 1, 1)
        let rota = ShiftWorkSettings(
            recurs: false,
            startingJdn: start,
            records: [ShiftWorkRecord(type: "d", length: 2)])
        XCTAssertEqual(rota.workTitle(for: start), "d")
        XCTAssertEqual(rota.workTitle(for: start + 1), "d")
        XCTAssertNil(rota.workTitle(for: start + 2))
    }

    func testShiftWorkSerializationRoundTrips() {
        let records = [
            ShiftWorkRecord(type: "d", length: 2),
            ShiftWorkRecord(type: "n", length: 3),
        ]
        let text = ShiftWorkSettings(records: records).serialized
        XCTAssertEqual(text, "d=2,n=3")
        XCTAssertEqual(ShiftWorkSettings.parse(text), records)
    }

    func testShiftWorkWithNoRecordsResolvesToNothing() {
        let rota = ShiftWorkSettings(startingJdn: Jdn(.shamsi, 1403, 1, 1), records: [])
        XCTAssertNil(rota.workTitle(for: Jdn(.shamsi, 1403, 1, 5)))
    }

    // MARK: - Cities

    func testCitiesDataLoads() {
        let cities = CitiesData.shared
        // 58 cities across 5 country groups in the bundled cities.json.
        XCTAssertEqual(cities.count, 58)
        // Tehran is the reference location for the Iranian calendar and must be present.
        guard let tehran = cities.first(where: { $0.key == "TEHRAN" }) else {
            return XCTFail("Tehran missing from cities.json")
        }
        XCTAssertEqual(tehran.countryCode, "ir")
        XCTAssertEqual(tehran.coordinates.latitude, 35.7, accuracy: 0.5)
        XCTAssertEqual(tehran.coordinates.longitude, 51.4, accuracy: 0.5)
        XCTAssertEqual(tehran.localizedName(for: .fa), "تهران")

        // Every city must carry usable coordinates.
        for city in cities where city.key != "CUSTOM" {
            XCTAssertTrue(
                (-90...90).contains(city.coordinates.latitude), "\(city.key) latitude")
            XCTAssertTrue(
                (-180...180).contains(city.coordinates.longitude), "\(city.key) longitude")
        }
    }
}
