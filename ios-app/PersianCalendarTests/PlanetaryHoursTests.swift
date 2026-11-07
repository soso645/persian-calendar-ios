import XCTest
@testable import PersianCalendar

/// The Android suite's `Planetary hours` test is entirely commented out, so there are no reference
/// vectors to port. These check the structural properties the algorithm must satisfy instead.
final class PlanetaryHoursTests: XCTestCase {

    private let tehran = Coordinates(latitude: 35.68, longitude: 51.42, elevation: 0)

    /// The ruling planet of each weekday, which is the classical origin of the day names.
    func testChaldeanRulerPerWeekday() {
        let expected: [(WeekDay, Body)] = [
            (.saturday, .saturn), (.sunday, .sun), (.monday, .moon), (.tuesday, .mars),
            (.wednesday, .mercury), (.thursday, .jupiter), (.friday, .venus),
        ]
        // 1403/1/1 is a Wednesday; walk a week from the preceding Saturday.
        var jdn = Jdn(.shamsi, 1403, 1, 1)
        while jdn.weekDay != .saturday { jdn = jdn - 1 }
        for (offset, pair) in expected.enumerated() {
            let day = jdn + offset
            XCTAssertEqual(day.weekDay, pair.0)
            XCTAssertEqual(chaldeanOrder[chaldeanIndex(from: day)].body, pair.1, "\(pair.0)")
        }
    }

    func testGeocentricPlanetsListExcludesSunAndMoon() {
        XCTAssertFalse(geocentricPlanetsList.contains(.sun))
        XCTAssertFalse(geocentricPlanetsList.contains(.moon))
        XCTAssertEqual(geocentricPlanetsList.count, 5)
        // Reverse Chaldean order, so Mercury (innermost of the five) comes first.
        XCTAssertEqual(geocentricPlanetsList.first, .mercury)
        XCTAssertEqual(geocentricPlanetsList.last, .saturn)
    }

    func testTwentyFourHoursCoverTheDayAndNight() {
        let jdn = Jdn(.shamsi, 1403, 1, 1)
        let now = Int(jdn.toDate().timeIntervalSince1970 * 1000) + 12 * 3_600_000

        let rows = planetaryHours(
            now: now,
            jdnForDayOffset: { jdn + $0 },
            sunriseSunset: { offset in
                let times = PrayTimes(
                    method: .Tehran,
                    year: (jdn + offset).toCivilDate().year,
                    month: (jdn + offset).toCivilDate().month,
                    dayOfMonth: (jdn + offset).toCivilDate().dayOfMonth,
                    offset: 3.5,
                    coordinates: tehran,
                    asrMethod: .standard,
                    highLatitudesMethod: .nightMiddle)
                return (times.sunrise, times.sunset)
            },
            isToday: true)

        // Twelve daylight hours plus twelve night hours.
        XCTAssertEqual(rows.count, 24)
        XCTAssertEqual(rows.filter(\.isDay).count, 12)
        XCTAssertEqual(rows.filter { !$0.isDay }.count, 12)

        // The first daylight hour is ruled by the day's own planet.
        let dayRuler = chaldeanOrder[chaldeanIndex(from: jdn)]
        XCTAssertEqual(rows.first?.planet, dayRuler)

        // Exactly one hour contains "now".
        XCTAssertEqual(rows.filter(\.upcoming).count, 1)

        // Consecutive hours follow the Chaldean sequence, wrapping round.
        for index in 1..<rows.count {
            let previous = chaldeanOrder.firstIndex(of: rows[index - 1].planet)!
            let current = chaldeanOrder.firstIndex(of: rows[index].planet)!
            XCTAssertEqual(
                current, (previous + 1) % chaldeanOrder.count,
                "hour \(index) broke the Chaldean sequence")
        }
    }

    func testNothingIsMarkedCurrentWhenNotToday() {
        let jdn = Jdn(.shamsi, 1403, 1, 1)
        let now = Int(jdn.toDate().timeIntervalSince1970 * 1000) + 12 * 3_600_000
        let rows = planetaryHours(
            now: now,
            jdnForDayOffset: { jdn + $0 },
            sunriseSunset: { _ in (6.0, 18.0) },
            isToday: false)
        XCTAssertEqual(rows.count, 24)
        XCTAssertTrue(rows.allSatisfy { !$0.upcoming })
    }
}
