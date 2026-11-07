import XCTest
@testable import PersianCalendar

/// Mirrors `Check black moon values`, `Check ascending node`, `Check nairAlSaif` and
/// `Check alulaBorealis` from the Android `AstronomyTests.kt`.
final class StarsAndNodesTests: XCTestCase {

    /// The Android helper: a position given as a sign plus degrees and arcminutes within it.
    private func position(_ zodiac: Zodiac, _ degrees: Int, _ minutes: Int) -> Double {
        Double(zodiac.rawValue) * 30 + Double(degrees) + Double(minutes) / 60.0
    }

    private func marchEquinox(persianYear: Int) -> AstroTime {
        let gregorianYear = CivilDate(PersianDate(year: persianYear, month: 1, dayOfMonth: 1)).year
        return seasons(gregorianYear).marchEquinox
    }

    /// The lunar apogee, or "black moon".
    func testBlackMoonValues() {
        let cases: [(Int, Double)] = [
            (1398, position(.aquarius, 25, 7)),
            (1400, position(.taurus, 16, 42)),
            (1401, position(.gemini, 27, 11)),
            (1402, position(.leo, 7, 59)),
            (1403, position(.virgo, 18, 46)),
        ]
        for (year, expected) in cases {
            XCTAssertEqual(
                expected, meanApogee(marchEquinox(persianYear: year)),
                accuracy: 0.15, "\(year)")
        }
    }

    func testAscendingNode() {
        let cases: [(Int, Double)] = [
            (1398, position(.cancer, 24, 31)),
            (1400, position(.gemini, 13, 39)),
            (1401, position(.taurus, 23, 42)),
            (1402, position(.taurus, 4, 23)),
            (1403, position(.aries, 15, 44)),
        ]
        for (year, expected) in cases {
            XCTAssertEqual(
                expected, meanAscendingNode(marchEquinox(persianYear: year)),
                accuracy: 0.15, "\(year)")
        }
    }

    func testNairAlSaif() {
        XCTAssertEqual(
            position(.gemini, 23, 25), nairAlSaif(marchEquinox(persianYear: 1402)),
            accuracy: 0.1)
    }

    func testAlulaBorealis() {
        XCTAssertEqual(
            position(.virgo, 6, 46), alulaBorealis(marchEquinox(persianYear: 1402)),
            accuracy: 0.25)
    }

    // MARK: - Beyond the Android suite

    /// The node sequence must alternate and advance, since `meanAscendingNode` relies on finding
    /// a bracketing pair.
    func testMoonNodeSequenceAlternatesAndAdvances() {
        let start = marchEquinox(persianYear: 1403)
        let events = Array(moonNodeSequence(after: start).prefix(8))
        XCTAssertEqual(events.count, 8)
        for index in events.indices {
            XCTAssertNotEqual(events[index].kind, .invalid)
            if index > 0 {
                XCTAssertNotEqual(
                    events[index].kind, events[index - 1].kind, "nodes must alternate")
                XCTAssertGreaterThan(
                    events[index].time.tt, events[index - 1].time.tt, "nodes must advance")
                // Successive crossings are about half a draconic month apart.
                let gap = events[index].time.tt - events[index - 1].time.tt
                XCTAssertEqual(gap, 13.6, accuracy: 0.6, "unexpected node spacing")
            }
        }
    }

    /// The stars are fixed, so their ecliptic longitude drifts only by precession — about
    /// 1.4° per century, and always forwards.
    func testStarLongitudesPrecessSlowly() {
        let earlier = nairAlSaif(marchEquinox(persianYear: 1350))
        let later = nairAlSaif(marchEquinox(persianYear: 1450))
        let drift = floorMod(later - earlier, 360)
        XCTAssertEqual(drift, 1.4, accuracy: 0.3, "precession over a century looks wrong")
    }
}
