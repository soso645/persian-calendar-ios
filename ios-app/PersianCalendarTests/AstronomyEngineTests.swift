import XCTest
@testable import PersianCalendar

/// Sanity checks on the Swift wrapper around the vendored Astronomy Engine C library.
///
/// These are not ported from the Android suite — they exist to prove the C bridge is wired up and
/// returning real values, against figures that can be checked independently.
final class AstronomyEngineTests: XCTestCase {

    /// 2024-03-20T03:06:00Z, the March equinox of 2024.
    private let equinox2024 = AstroTime(year: 2024, month: 3, day: 20, hour: 3, minute: 6, second: 0)

    func testTimeRoundTripsThroughMilliseconds() {
        // 2024-03-20T03:06:00Z
        let millis = 1_710_903_960_000
        let time = AstroTime.fromMillisecondsSince1970(millis)
        XCTAssertEqual(time.toMillisecondsSince1970(), millis)
        XCTAssertEqual(time.ut, equinox2024.ut, accuracy: 1e-9)
    }

    func testSunPositionAtMarchEquinoxIsNearZeroLongitude() {
        let elon = sunPosition(equinox2024).elon
        // At the March equinox the Sun's apparent ecliptic longitude passes through 0/360.
        let distanceFromZero = min(elon, 360 - elon)
        XCTAssertLessThan(distanceFromZero, 0.02, "sun elon was \(elon)")
    }

    func testSeasonsMatchesKnownEquinox() {
        let info = seasons(2024)
        // March equinox 2024 was 2024-03-20T03:06Z.
        XCTAssertEqual(info.marchEquinox.ut, equinox2024.ut, accuracy: 0.5 / 24 / 60)
        // Ordering must hold across the year.
        XCTAssertLessThan(info.marchEquinox, info.juneSolstice)
        XCTAssertLessThan(info.juneSolstice, info.septemberEquinox)
        XCTAssertLessThan(info.septemberEquinox, info.decemberSolstice)
    }

    func testMoonDistanceIsWithinItsOrbitalRange() {
        let info = libration(equinox2024)
        // The Moon's distance varies roughly between 356,500 and 406,700 km.
        XCTAssertGreaterThan(info.distKm, 356_000)
        XCTAssertLessThan(info.distKm, 407_000)
        // Apparent diameter runs about 0.49-0.57 degrees.
        XCTAssertGreaterThan(info.diamDeg, 0.48)
        XCTAssertLessThan(info.diamDeg, 0.58)

        // `libration` reports the Moon's position against the *mean* equinox of date, while
        // `eclipticGeoMoon` uses the *true* equinox — so the two differ by the nutation in
        // longitude, up to about 0.005 degrees. Agreement to that level shows both are live.
        let moon = eclipticGeoMoon(equinox2024)
        XCTAssertEqual(moon.lat, info.mlat, accuracy: 0.01)
        XCTAssertEqual(moon.lon, info.mlon, accuracy: 0.01)
    }

    func testRiseAndSetInTehran() {
        let tehran = Observer(35.6892, 51.3890, 1200)
        let startOfDay = AstroTime(year: 2024, month: 3, day: 20, hour: 0, minute: 0, second: 0)
        guard let sunrise = searchRiseSet(.sun, tehran, .rise, startOfDay, 1),
            let sunset = searchRiseSet(.sun, tehran, .set, startOfDay, 1)
        else { return XCTFail("no rise/set found") }

        XCTAssertLessThan(sunrise, sunset)
        // Near the equinox, day length is close to 12 hours everywhere.
        let dayLengthHours = (sunset.ut - sunrise.ut) * 24
        XCTAssertEqual(dayLengthHours, 12, accuracy: 0.3)
    }

    func testGeoAndHelioVectorsAreConsistentForEarth() {
        // The Sun seen from Earth and the Earth seen from the Sun are opposite vectors.
        let sunFromEarth = geoVector(.sun, equinox2024, .none)
        let earthFromSun = helioVector(.earth, equinox2024)
        XCTAssertEqual(sunFromEarth.x, -earthFromSun.x, accuracy: 1e-9)
        XCTAssertEqual(sunFromEarth.y, -earthFromSun.y, accuracy: 1e-9)
        XCTAssertEqual(sunFromEarth.z, -earthFromSun.z, accuracy: 1e-9)
        // Earth-Sun distance is about 1 AU.
        XCTAssertEqual(sunFromEarth.length(), 1.0, accuracy: 0.02)
    }

    func testSearchFindsAZeroCrossing() {
        // The Sun's ecliptic longitude wraps past 360 at the March equinox; search for the moment
        // its sine crosses zero going positive.
        let t1 = AstroTime(year: 2024, month: 3, day: 19, hour: 0, minute: 0, second: 0)
        let t2 = AstroTime(year: 2024, month: 3, day: 21, hour: 0, minute: 0, second: 0)
        let found = search(t1: t1, t2: t2, toleranceSeconds: 1) { time in
            let elon = sunPosition(time).elon
            return elon > 180 ? elon - 360 : elon
        }
        guard let found else { return XCTFail("search did not converge") }
        XCTAssertEqual(found.ut, equinox2024.ut, accuracy: 0.5 / 24 / 60)
    }

    func testEclipseSearchReturnsAKnownEclipse() {
        // The total solar eclipse of 2024-04-08.
        let start = AstroTime(year: 2024, month: 4, day: 1, hour: 0, minute: 0, second: 0)
        guard let eclipse = searchGlobalSolarEclipse(start) else {
            return XCTFail("no solar eclipse found")
        }
        XCTAssertEqual(eclipse.kind, .total)
        let peak = eclipse.peak.date
        var utc = Foundation.Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(utc.component(.year, from: peak), 2024)
        XCTAssertEqual(utc.component(.month, from: peak), 4)
        XCTAssertEqual(utc.component(.day, from: peak), 8)
    }

    func testMoonNodeSearchAlternates() {
        var time = AstroTime(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        var previous: NodeEventKind?
        for _ in 0..<6 {
            let node = moonNodesAfter(time)
            XCTAssertNotEqual(node.kind, .invalid)
            if let previous { XCTAssertNotEqual(node.kind, previous, "nodes must alternate") }
            previous = node.kind
            time = node.time.addDays(0.01)
        }
    }
}
