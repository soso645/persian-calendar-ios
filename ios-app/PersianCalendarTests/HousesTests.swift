import XCTest
@testable import PersianCalendar

/// Mirrors `Ascendant correctness` and `Check lots` from the Android `AstronomyTests.kt`.
///
/// These exercise the whole chain at once — `seasons` → `rotationEctEqd` → `siderealTime` → the
/// Placidus solver — against 82 exact reference values, so a discrepancy anywhere shows up here.
final class HousesTests: XCTestCase {

    private let tehran = Coordinates(latitude: 35.68, longitude: 51.42, elevation: 0)

    private func marchEquinox(persianYear: Int) -> AstroTime {
        let gregorianYear = CivilDate(PersianDate(year: persianYear, month: 1, dayOfMonth: 1)).year
        return seasons(gregorianYear).marchEquinox
    }

    func testAscendantCorrectness() {
        let ascendants: [Double] = [
            165.29847801886166, 236.29668499183026, 321.797191638284,
            80.34263360923649, 153.48105769394334, 225.9653124106477,
            304.6980552072615, 64.62545992403068, 143.33024864679658,
            215.11313481654395, 291.38637627325454, 54.76578575422565,
            134.72543967324845, 207.94257567520026, 282.13323220688267,
            40.57586845190173, 128.0385988488901, 199.39109345375834,
            270.9214212751657, 26.357835345588768, 117.51716101735667,
            190.71799947614733, 263.28083807687597, 9.726529738377508,
            110.0952666028478, 180.80568019929513, 250.47258409845392,
            350.25338333258026, 97.29010414477642, 169.61149223122686,
            241.38395110721706, 329.35143674069417, 88.56361718692915,
            162.50276019387098, 233.7188545299278, 322.55668454433277,
            80.71131124720335, 154.8804221204217, 227.34730063093093,
            305.90002157601714, 69.70791148916334,
        ]
        let midheavens: [Double] = [
            73.6674692915762, 156.8359554622392, 246.5253026081649,
            329.55822788765704, 60.13096053952552, 143.5468865952335,
            233.8099812381863, 314.14168287940015, 48.0104581652713,
            130.0971717634887, 222.19307876778737, 305.7612554619727,
            37.327133874385936, 121.53875535246021, 213.04094212400594,
            295.12340178053773, 28.787566137967417, 111.64248747789384,
            200.71639167251874, 285.7116593454741, 15.07595653342105,
            101.87160094907495, 191.60194463824791, 275.66013578654133,
            5.373472585234822, 90.88935102525966, 175.36387856929116,
            264.3277360284461, 349.1018998359573, 78.49561787403366,
            163.48287952332885, 251.54926299869965, 338.69238641161337,
            70.51027198602742, 153.4841648259337, 247.0387030539855,
            329.96107258615484, 61.762612284235615, 145.29968044985748,
            234.77117761711645, 318.8433129667867,
        ]

        for (index, year) in (1380...1420).enumerated() {
            let time = marchEquinox(persianYear: year)
            let cusps = houses(
                latitude: tehran.latitude, longitude: tehran.longitude, time: time)
            XCTAssertEqual(ascendants[index], cusps[0], accuracy: 1.0e-5, "\(year) ascendant")
            XCTAssertEqual(midheavens[index], cusps[9], accuracy: 1.0e-5, "\(year) midheaven")
        }
    }

    /// Smoke test over a wide span, as in the Android suite: the Placidus solver must not diverge.
    func testHousesAreWellFormedAcrossCenturies() {
        for year in stride(from: 1300, through: 1500, by: 7) {
            let time = marchEquinox(persianYear: year)
            let cusps = houses(
                latitude: tehran.latitude, longitude: tehran.longitude, time: time)
            XCTAssertEqual(cusps.count, 12)
            for (index, cusp) in cusps.enumerated() {
                XCTAssertFalse(cusp.isNaN, "\(year) house \(index + 1) is NaN")
                XCTAssertTrue(
                    (0..<360).contains(cusp), "\(year) house \(index + 1) out of range: \(cusp)")
            }
            // Opposite houses must sit exactly 180° apart.
            for index in 0..<6 {
                let opposite = floorMod(cusps[index] + 180, 360)
                XCTAssertEqual(
                    opposite, cusps[index + 6], accuracy: 1.0e-9,
                    "\(year) house \(index + 1) and \(index + 7) are not opposed")
            }
        }
    }

    /// Mirrors `Check lots`, against a Persian calendar printed in 1225 AP.
    ///
    /// https://upload.wikimedia.org/wikipedia/commons/3/32/یک_تقویم_فارسی_از_سال_۱۲۲۵_شمسی.pdf
    func testLots() {
        let time = marchEquinox(persianYear: 1225)
        let cusps = houses(latitude: tehran.latitude, longitude: tehran.longitude, time: time)
        let ascendant = cusps[0]
        let diurnal = isDiurnal(houses: cusps, time: time)

        let expected: [(Lot, Zodiac)] = [
            (.fortune, .aries),
            (.sultan, .pisces),
            (.wheat, .sagittarius),
            (.grapes, .scorpio),
        ]
        for (lot, zodiac) in expected {
            let longitude = lot.calculate(
                ascendant: ascendant, isDiurnal: diurnal, time: time)
            XCTAssertEqual(Zodiac.fromTropical(longitude), zodiac, "\(lot)")
        }
    }

    /// The Sun is below the horizon at the moment of the March equinox in Tehran in 1225 AP, so
    /// the nocturnal formulas are the ones the lot test above exercises.
    func testDiurnalDetectionIsConsistentWithTheSunPosition() {
        for year in [1225, 1380, 1400, 1403] {
            let time = marchEquinox(persianYear: year)
            let cusps = houses(
                latitude: tehran.latitude, longitude: tehran.longitude, time: time)
            let diurnal = isDiurnal(houses: cusps, time: time)

            // Cross-check against the Sun's actual altitude for the same moment.
            let observer = tehran.toObserver()
            let equatorial = equator(.sun, time, observer, .ofDate, .corrected)
            let horizontal = horizon(
                time, observer, equatorial.ra, equatorial.dec, .none)
            XCTAssertEqual(
                diurnal, horizontal.altitude > 0,
                "\(year): chart says diurnal=\(diurnal) but Sun altitude is \(horizontal.altitude)")
        }
    }
}
