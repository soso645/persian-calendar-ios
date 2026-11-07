import XCTest
@testable import PersianCalendar

/// Mirrors `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/PrayTimeTests.kt`.
///
/// The Kotlin test builds a `GregorianCalendar` in a fixed-offset zone and lets
/// `Coordinates.calculatePrayTimes` extract year/month/day and the UTC offset from it. With fixed
/// offsets like "GMT-4:00" that reduces to passing the offset directly, which is what happens here.
final class PrayTimeTests: XCTestCase {

    private let waterloo = Coordinates(latitude: 43.0, longitude: -80.0, elevation: 0.0)

    private func times(
        _ coordinates: Coordinates,
        _ method: CalculationMethod,
        _ asrMethod: AsrMethod,
        year: Int, month: Int, day: Int, offset: Double
    ) -> PrayTimes {
        PrayTimes(
            method: method,
            year: year, month: month, dayOfMonth: day,
            offset: offset,
            coordinates: coordinates,
            asrMethod: asrMethod,
            highLatitudesMethod: .nightMiddle,
            midnightMethod: method.defaultMidnight
        )
    }

    private func assertClock(
        _ expected: (Int, Int), _ actual: Double, _ label: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let pair = Clock(actual).toHoursAndMinutesPair()
        XCTAssertEqual(pair.hours, expected.0, "\(label) hours", file: file, line: line)
        XCTAssertEqual(pair.minutes, expected.1, "\(label) minutes", file: file, line: line)
    }

    func testSmokeTestDifferentCalculationMethods() {
        for method in CalculationMethod.allCases {
            _ = times(waterloo, method, .standard, year: 2018, month: 9, day: 5, offset: -4)
        }
    }

    func testPrayTimesCalculationsCorrectness() {
        // https://praytimes.org/code/v2/js/examples/monthly.htm

        var p = times(waterloo, .MWL, .standard, year: 2018, month: 9, day: 5, offset: -4)
        assertClock((5, 9), p.fajr, "MWL fajr")
        assertClock((6, 48), p.sunrise, "MWL sunrise")
        assertClock((13, 18), p.dhuhr, "MWL dhuhr")
        assertClock((16, 57), p.asr, "MWL asr")
        assertClock((19, 47), p.maghrib, "MWL maghrib")
        assertClock((21, 21), p.isha, "MWL isha")

        p = times(waterloo, .ISNA, .standard, year: 2018, month: 9, day: 5, offset: -4)
        assertClock((5, 27), p.fajr, "ISNA fajr")
        assertClock((6, 48), p.sunrise, "ISNA sunrise")
        assertClock((13, 18), p.dhuhr, "ISNA dhuhr")
        assertClock((16, 57), p.asr, "ISNA asr")
        assertClock((19, 47), p.maghrib, "ISNA maghrib")
        assertClock((21, 8), p.isha, "ISNA isha")

        p = times(waterloo, .Egypt, .hanafi, year: 2018, month: 9, day: 5, offset: -4)
        assertClock((4, 59), p.fajr, "Egypt fajr")
        assertClock((6, 48), p.sunrise, "Egypt sunrise")
        assertClock((13, 18), p.dhuhr, "Egypt dhuhr")
        assertClock((17, 53), p.asr, "Egypt asr")
        assertClock((19, 47), p.maghrib, "Egypt maghrib")
        assertClock((21, 24), p.isha, "Egypt isha")

        p = times(waterloo, .Makkah, .standard, year: 2018, month: 9, day: 5, offset: -4)
        assertClock((5, 6), p.fajr, "Makkah fajr")
        assertClock((6, 48), p.sunrise, "Makkah sunrise")
        assertClock((13, 18), p.dhuhr, "Makkah dhuhr")
        assertClock((16, 57), p.asr, "Makkah asr")
        assertClock((19, 47), p.maghrib, "Makkah maghrib")
        assertClock((21, 17), p.isha, "Makkah isha")

        p = times(waterloo, .Karachi, .standard, year: 2018, month: 9, day: 5, offset: -4)
        assertClock((5, 9), p.fajr, "Karachi fajr")
        assertClock((6, 48), p.sunrise, "Karachi sunrise")
        assertClock((13, 18), p.dhuhr, "Karachi dhuhr")
        assertClock((16, 57), p.asr, "Karachi asr")
        assertClock((19, 47), p.maghrib, "Karachi maghrib")
        assertClock((21, 27), p.isha, "Karachi isha")

        p = times(waterloo, .Jafari, .standard, year: 2018, month: 9, day: 5, offset: -4)
        assertClock((5, 21), p.fajr, "Jafari fajr")
        assertClock((6, 48), p.sunrise, "Jafari sunrise")
        assertClock((13, 18), p.dhuhr, "Jafari dhuhr")
        assertClock((16, 57), p.asr, "Jafari asr")
        assertClock((20, 5), p.maghrib, "Jafari maghrib")
        assertClock((21, 2), p.isha, "Jafari isha")

        p = times(waterloo, .Tehran, .standard, year: 2018, month: 9, day: 5, offset: -4)
        assertClock((5, 10), p.fajr, "Tehran fajr")
        assertClock((6, 48), p.sunrise, "Tehran sunrise")
        assertClock((13, 18), p.dhuhr, "Tehran dhuhr")
        assertClock((16, 57), p.asr, "Tehran asr")
        assertClock((20, 8), p.maghrib, "Tehran maghrib")
        assertClock((21, 2), p.isha, "Tehran isha")

        let kualaLumpur = Coordinates(
            latitude: 3.147778, longitude: 101.695278, elevation: 0.0)
        p = times(kualaLumpur, .Tehran, .standard, year: 2019, month: 6, day: 9, offset: 8)
        assertClock((5, 49), p.fajr, "KL fajr")
        assertClock((7, 3), p.sunrise, "KL sunrise")
        assertClock((13, 12), p.dhuhr, "KL dhuhr")
        assertClock((16, 38), p.asr, "KL asr")
        assertClock((19, 37), p.maghrib, "KL maghrib")
        assertClock((20, 18), p.isha, "KL isha")
    }
}
