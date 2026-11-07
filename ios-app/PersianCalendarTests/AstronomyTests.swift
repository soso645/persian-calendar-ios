import XCTest
@testable import PersianCalendar

/// Mirrors `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/AstronomyTests.kt`,
/// covering the parts whose subjects are ported (Zodiac, LunarAge, Season, ChineseZodiac).
final class AstronomyTests: XCTestCase {

    // MARK: - Lunar age

    func testLunarAge() {
        // https://github.com/BGCX262/zweer-gdr-svn-to-git/blob/6d85903/trunk/library/Zwe/Weather/Moon.php
        let expectedDays = [
            1.84566, 5.53699, 9.22831, 12.91963, 16.61096, 20.30228, 23.99361, 27.68493,
        ]
        for (index, expected) in expectedDays.enumerated() {
            let lunarAge = LunarAge.fromDegrees((Double(index) + 0.5) * (360 / 8))
            XCTAssertEqual(expected, lunarAge.days, accuracy: 1.0e-5)
            XCTAssertEqual((index + 1) % 8, lunarAge.toPhase().rawValue)
        }
        XCTAssertEqual(.newMoon, LunarAge.fromDegrees(340.0).toPhase())
        XCTAssertEqual(.newMoon, LunarAge.fromDegrees(0.0).toPhase())
        XCTAssertEqual(.firstQuarter, LunarAge.fromDegrees(90.0).toPhase())
        XCTAssertEqual(.fullMoon, LunarAge.fromDegrees(180.0).toPhase())
        XCTAssertEqual(.thirdQuarter, LunarAge.fromDegrees(270.0).toPhase())
    }

    func testSouthernHemisphereInMoonDraw() {
        let southern = Coordinates(latitude: -10.0, longitude: 10.0, elevation: 10.0)
        XCTAssertEqual(
            LunarAge.Phase.waxingCrescent.emoji(coordinates: nil),
            LunarAge.Phase.waningCrescent.emoji(coordinates: southern))

        // Just make sure nothing blows up across a wide range.
        for degrees in -720...720 {
            let phase = LunarAge.fromDegrees(Double(degrees)).toPhase()
            _ = "\(phase) \(phase.emoji(coordinates: nil)) \(phase.emoji(coordinates: southern))"
        }
    }

    // MARK: - Zodiac

    func testZodiacFromPersianCalendar() {
        for month in 1...12 {
            XCTAssertEqual(
                Zodiac.allCases[month - 1],
                Zodiac.fromPersianCalendar(PersianDate(year: 1400, month: month, dayOfMonth: 1)))
        }
        XCTAssertEqual(
            .leo, Zodiac.fromPersianCalendar(PersianDate(year: 1400, month: 5, dayOfMonth: 1)))
    }

    func testZodiacFromEcliptic() {
        let longitudes = [10, 40, 60, 100, 130, 140, 180, 230, 260, 280, 310, 320, 350]
        let expected: [Zodiac] = [.pisces] + Zodiac.allCases
        for (longitude, zodiac) in zip(longitudes, expected) {
            XCTAssertEqual(zodiac, Zodiac.fromIau(Double(longitude)), "\(longitude)")
        }

        let tropicalLongitudes = (0...11).map { 20 + $0 * 30 }
        let tropicalExpected: [Zodiac] = Zodiac.allCases + [.pisces]
        for (longitude, zodiac) in zip(tropicalLongitudes, tropicalExpected) {
            XCTAssertEqual(zodiac, Zodiac.fromTropical(Double(longitude)), "\(longitude)")
        }
    }

    func testZodiacCenterOfRange() {
        let iauCenters = [
            42.17, 72.3, 106.46, 127.39, 154.32, 198.755,
            233.37, 256.915, 286.875, 307.105, 330.15, 370.88,
        ]
        for (center, zodiac) in zip(iauCenters, Zodiac.allCases) {
            let average = zodiac.iauRange.reduce(0, +) / Double(zodiac.iauRange.count)
            XCTAssertEqual(center, average, accuracy: 1.0e-10, "\(zodiac)")
        }
        for (index, zodiac) in Zodiac.allCases.enumerated() {
            let average = zodiac.tropicalRange.reduce(0, +) / Double(zodiac.tropicalRange.count)
            XCTAssertEqual(Double(index) * 30.0 + 15, average, accuracy: 1.0e-10, "\(zodiac)")
        }
    }

    // MARK: - Seasons

    func testSeasonFromPersianCalendar() {
        func seasons(at coordinates: Coordinates?) -> [Season] {
            (1...12).map { month in
                let jdn = Jdn(PersianDate(year: 1400, month: month, dayOfMonth: 28))
                let millis = Int(jdn.toDate().timeIntervalSince1970 * 1000)
                return Season.fromTimeInMillis(millis, coordinates: coordinates)
            }
        }

        let noLocation = seasons(at: nil)
        for (range, season) in [
            (1...3, Season.spring), (4...6, .summer), (7...9, .autumn), (10...12, .winter),
        ] {
            for month in range {
                XCTAssertEqual(season, noLocation[month - 1], "month \(month)")
            }
        }

        let kathmandu = Coordinates(latitude: 27.7172, longitude: 85.324, elevation: 1400.0)
        XCTAssertEqual(seasons(at: kathmandu), noLocation)

        let nairobi = Coordinates(latitude: -1.286389, longitude: 36.817222, elevation: 1795.0)
        let southern = seasons(at: nairobi)
        for (range, season) in [
            (1...3, Season.autumn), (4...6, .winter), (7...9, .spring), (10...12, .summer),
        ] {
            for month in range {
                XCTAssertEqual(season, southern[month - 1], "month \(month)")
            }
        }
    }

    func testSeasonEquinox() {
        let info = seasons(2020)
        XCTAssertEqual(info.marchEquinox.toMillisecondsSince1970(), 1_584_676_196_290)
        XCTAssertEqual(info.juneSolstice.toMillisecondsSince1970(), 1_592_689_411_284)
        XCTAssertEqual(info.septemberEquinox.toMillisecondsSince1970(), 1_600_781_459_379)
        XCTAssertEqual(info.decemberSolstice.toMillisecondsSince1970(), 1_608_544_962_334)
    }

    // MARK: - Chinese zodiac

    func testIranianAnimalYearName() {
        XCTAssertEqual(
            .ox,
            ChineseZodiac.fromPersianCalendar(PersianDate(year: 1400, month: 1, dayOfMonth: 1)))
        XCTAssertEqual(
            .tiger,
            ChineseZodiac.fromPersianCalendar(PersianDate(year: 1401, month: 1, dayOfMonth: 1)))

        let expected: [ChineseZodiac] = [
            .monkey, .rooster, .dog, .pig, .rat, .ox,
            .tiger, .rabbit, .dragon, .snake, .horse, .goat,
        ]
        for (zodiac, year) in zip(expected, 1395...1406) {
            XCTAssertEqual(
                zodiac,
                ChineseZodiac.fromPersianCalendar(
                    PersianDate(year: year, month: 1, dayOfMonth: 1)),
                "\(year)")
        }

        // Must not crash in negative years.
        for year in -20...20 {
            _ = ChineseZodiac.fromPersianCalendar(PersianDate(year: year, month: 1, dayOfMonth: 1))
        }
    }

    /// https://en.wikipedia.org/wiki/Chinese_zodiac#Compatibility
    func testMatchesWithCompatibilityTable() {
        let bestMatches: [Set<ChineseZodiac>] = [
            [.dragon, .monkey, .ox], [.rooster, .snake, .rat], [.horse, .dog, .pig],
            [.pig, .goat, .dog], [.rat, .monkey, .rooster], [.ox, .rooster, .monkey],
            [.dog, .tiger, .goat], [.rabbit, .pig, .horse], [.dragon, .rat, .snake],
            [.snake, .ox, .dragon], [.tiger, .horse, .rabbit], [.rabbit, .goat, .tiger],
        ]
        for (matches, yearZodiac) in zip(bestMatches, ChineseZodiac.allCases) {
            for match in matches {
                let compatibility = yearZodiac.compatibility(with: match)
                XCTAssertTrue(
                    [.best, .better].contains(compatibility),
                    "\(yearZodiac) with \(match) was \(compatibility)")
            }
        }

        let neutralMatches: [Set<ChineseZodiac>] = [
            [.pig, .tiger, .dog, .snake, .rabbit, .rooster, .rat],
            [.monkey, .dog, .rabbit, .tiger, .dragon, .pig, .ox],
            [.rabbit, .dragon, .rooster, .rat, .goat, .ox, .tiger],
            [.tiger, .monkey, .rabbit, .ox, .horse, .rat, .snake],
            [.tiger, .snake, .horse, .goat, .pig, .ox, .dragon],
            [.horse, .dragon, .goat, .dog, .rabbit, .rat, .snake],
            [.snake, .rabbit, .dragon, .rooster, .pig, .monkey, .horse],
            [.snake, .goat, .dragon, .monkey, .rooster, .dog, .tiger],
            [.monkey, .dog, .ox, .goat, .rabbit, .rooster, .horse],
            [.horse, .rooster, .goat, .pig, .tiger, .monkey, .rat],
            [.monkey, .pig, .rat, .ox, .snake, .goat, .dog],
            [.rat, .rooster, .dog, .dragon, .horse, .ox, .pig],
        ]
        for (matches, yearZodiac) in zip(neutralMatches, ChineseZodiac.allCases) {
            for match in matches {
                XCTAssertEqual(
                    .neutral, yearZodiac.compatibility(with: match),
                    "\(yearZodiac) with \(match)")
            }
        }

        let worseMatches: [ChineseZodiac] = [
            .horse, .goat, .monkey, .rooster, .dog, .pig,
            .rat, .ox, .tiger, .rabbit, .dragon, .snake,
        ]
        for (match, yearZodiac) in zip(worseMatches, ChineseZodiac.allCases) {
            XCTAssertEqual(
                .worse, yearZodiac.compatibility(with: match), "\(yearZodiac) with \(match)")
        }

        let worstMatches: [ChineseZodiac] = [
            .goat, .horse, .snake, .dragon, .rabbit, .tiger,
            .ox, .rat, .pig, .dog, .rooster, .monkey,
        ]
        for (match, yearZodiac) in zip(worstMatches, ChineseZodiac.allCases) {
            XCTAssertEqual(
                .worst, yearZodiac.compatibility(with: match), "\(yearZodiac) with \(match)")
        }
    }

    /// https://en.wikipedia.org/wiki/Chinese_zodiac#Signs
    func testMatchesWithMiscChineseZodiacDetails() {
        XCTAssertEqual(ChineseZodiac.rat.yinYang, .yang)
        XCTAssertEqual(ChineseZodiac.goat.yinYang, .yin)
        XCTAssertEqual(ChineseZodiac.dragon.trin, 1)

        let elements: [ChineseZodiac.FixedElement] = [
            .water, .earth, .wood, .wood, .earth, .fire,
            .fire, .earth, .metal, .metal, .earth, .water,
        ]
        for (index, element) in elements.enumerated() {
            XCTAssertEqual(element, ChineseZodiac.allCases[index].fixedElement)
        }
    }

    // MARK: - Abjad and angles

    /// Mirrors `Check Abjad conversion` from the Android suite.
    func testAbjadConversion() {
        let cases: [(Int, String)] = [
            (1, "ا"), (2, "ب"), (3, "ج"), (4, "د"), (5, "ه"), (6, "و"), (7, "ز"), (8, "ح"),
            (9, "ط"), (10, "ی"), (11, "یا"), (12, "یب"), (13, "یج"), (14, "ید"), (15, "یه"),
            (16, "یو"), (17, "یز"), (18, "یح"), (19, "یط"), (20, "ک"), (21, "کا"), (22, "کب"),
            (23, "کج"), (24, "کد"), (25, "که"), (26, "کو"), (27, "کز"), (28, "کح"), (29, "کط"),
            (30, "ل"), (31, "لا"),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(expected, Abjad.toAbjad(input), "\(input)")
        }
        XCTAssertEqual("۰", Abjad.toAbjad(0))
    }

    /// Mirrors `Check angle roundness` from the Android suite.
    func testAngleRoundness() {
        let cases: [(Double, String)] = [
            (27 + 59 / 60.0, "\u{200E}۲۷°:۵۹’\u{200E}"),
            (27 + 59.6 / 60.0, "\u{200E}۲۸°:۰۰’\u{200E}"),
            (27.99, "\u{200E}۲۷°:۵۹’\u{200E}"),
            (27.996, "\u{200E}۲۸°:۰۰’\u{200E}"),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(expected, formatAngle(input), "\(input)")
        }
    }

    // MARK: - Tithi

    /// The tithi cycles 1...30 and must advance roughly one step per day.
    func testTithiCyclesThroughALunarMonth() {
        let start = Jdn(PersianDate(year: 1403, month: 1, dayOfMonth: 1))
        var seen = Set<Int>()
        for offset in 0..<30 {
            let millis = Int((start + offset).toDate().timeIntervalSince1970 * 1000)
            let tee = 719_162 + Double(millis) / 86_400_000
            let day = Tithi.hinduLunarDayFromMoment(tee)
            XCTAssertTrue((1...30).contains(day), "tithi out of range: \(day)")
            seen.insert(day)
            XCTAssertFalse(Tithi.tithiName(timeMillis: millis).isEmpty)
        }
        // A 30-day sweep should cover most of the 30 tithis.
        XCTAssertGreaterThan(seen.count, 25, "tithi barely advanced across a month")
    }

    // MARK: - Moon in Scorpio

    /// Cross-checks the Scorpio boundaries against the Zodiac ranges they are derived from.
    func testMoonInScorpioRangeCoversTropicalAndIau() {
        XCTAssertEqual(Zodiac.scorpioRange.lowerBound, Zodiac.scorpio.tropicalRange[0])
        XCTAssertEqual(Zodiac.scorpioRange.lowerBound, 210.0)
        // Upper bound is where Sagittarius begins on the IAU boundaries.
        XCTAssertEqual(Zodiac.scorpioRange.upperBound, 271.26, accuracy: 1e-9)
    }

    func testMoonInScorpioStateIsConsistentWithLongitude() {
        // Scan a lunar month; every day the state must agree with the midnight longitudes.
        let start = Jdn(PersianDate(year: 1403, month: 1, dayOfMonth: 1))
        var sawBorjiOrFalaki = false
        var sawStart = false
        var sawEnd = false
        for offset in 0..<30 {
            let jdn = start + offset
            let state = moonInScorpioState(jdn: jdn)
            let todayIn = isMoonInScorpio(jdn: jdn, hourOfDay: 0)
            let tomorrowIn = isMoonInScorpio(jdn: jdn + 1, hourOfDay: 0)
            switch state {
            case .borji, .falaki:
                sawBorjiOrFalaki = true
                XCTAssertTrue(todayIn && tomorrowIn, "day \(offset)")
            case .start:
                sawStart = true
                XCTAssertTrue(tomorrowIn && !todayIn, "day \(offset)")
            case .end:
                sawEnd = true
                XCTAssertTrue(todayIn && !tomorrowIn, "day \(offset)")
            case nil:
                XCTAssertFalse(todayIn || tomorrowIn, "day \(offset)")
            }
        }
        // A lunar month must contain one full passage through Scorpio.
        XCTAssertTrue(sawStart, "no Scorpio entry found in the month")
        XCTAssertTrue(sawEnd, "no Scorpio exit found in the month")
        XCTAssertTrue(sawBorjiOrFalaki, "no full day in Scorpio found in the month")
    }
}
