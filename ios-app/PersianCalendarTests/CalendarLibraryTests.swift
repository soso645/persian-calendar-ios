import XCTest
@testable import PersianCalendar

/// Mirrors `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/CalendarLibraryTests.kt`.
final class CalendarLibraryTests: XCTestCase {

    override func tearDown() {
        IslamicDate.useUmmAlQura = false
        IslamicDate.islamicOffset = 0
        super.tearDown()
    }

    func testIslamicCalendarCalculationsCorrectness() {
        for entry in [
            [2453767, 1427, 1, 1],
            [2455658, 1432, 5, 2],
            // [2458579, 1440, 7, 29], [2458580, 1440, 8, 1]
        ] {
            let reference = IslamicDate(year: entry[1], month: entry[2], dayOfMonth: entry[3])
            XCTAssertEqual(entry[0], reference.toJdn())
            let converted = IslamicDate(jdn: entry[0])

            XCTAssertEqual(entry[1], converted.year)
            XCTAssertEqual(entry[2], converted.month)
            XCTAssertEqual(entry[3], converted.dayOfMonth)

            XCTAssertEqual(entry[0], converted.toJdn())
            XCTAssertEqual(reference, IslamicDate(jdn: reference.toJdn()))
        }

        for entry in [
            [2016, 10, 3, 1438, 1, 1],
            [2016, 11, 1, 1438, 2, 1],
            [2016, 12, 1, 1438, 3, 1],
            [2016, 12, 31, 1438, 4, 1],
            [2017, 1, 30, 1438, 5, 1],
            [2017, 2, 28, 1438, 6, 1],
            [2017, 3, 30, 1438, 7, 1],
            [2017, 4, 28, 1438, 8, 1],
            [2017, 5, 27, 1438, 9, 1],
            [2017, 6, 26, 1438, 10, 1],
            [2017, 7, 25, 1438, 11, 1],
            [2017, 8, 23, 1438, 12, 1],
            [2017, 9, 22, 1439, 1, 1],
            [2017, 10, 21, 1439, 2, 1],
            [2017, 11, 20, 1439, 3, 1],
            [2017, 12, 20, 1439, 4, 1],
            [2018, 1, 19, 1439, 5, 1],
            [2018, 2, 18, 1439, 6, 1],
            [2018, 3, 19, 1439, 7, 1],
            [2018, 4, 18, 1439, 8, 1],
            [2018, 5, 17, 1439, 9, 1],
            [2018, 6, 15, 1439, 10, 1],
            [2018, 7, 15, 1439, 11, 1],
            [2018, 8, 13, 1439, 12, 1],
            [2018, 9, 11, 1440, 1, 1],
            [2018, 10, 11, 1440, 2, 1],
            [2018, 11, 9, 1440, 3, 1],
            [2018, 12, 9, 1440, 4, 1],
            [2019, 1, 8, 1440, 5, 1],
            [2019, 2, 7, 1440, 6, 1],
        ] {
            let jdn = CivilDate(year: entry[0], month: entry[1], dayOfMonth: entry[2]).toJdn()
            let islamicDate = IslamicDate(year: entry[3], month: entry[4], dayOfMonth: entry[5])

            XCTAssertEqual(jdn, islamicDate.toJdn())
            XCTAssertEqual(islamicDate, IslamicDate(jdn: jdn))
        }

        IslamicDate.useUmmAlQura = true
        for (civil, islamic) in [
            ([2015, 3, 14], [1436, 5, 23]),
            ([1999, 4, 1], [1419, 12, 15]),
            ([1989, 2, 25], [1409, 7, 19]),
        ] {
            let jdn = CivilDate(year: civil[0], month: civil[1], dayOfMonth: civil[2]).toJdn()
            let islamicDate = IslamicDate(
                year: islamic[0], month: islamic[1], dayOfMonth: islamic[2])

            XCTAssertEqual(jdn, islamicDate.toJdn())
            XCTAssertEqual(islamicDate, IslamicDate(jdn: jdn))
        }
        IslamicDate.useUmmAlQura = false
    }

    func testPersianCalendarConvertingToAndFromJdn() {
        XCTAssertEqual(PersianDate(year: 1398, month: 1, dayOfMonth: 1).toJdn(), 2458564)
        let startJdn = CivilDate(year: 1750, month: 1, dayOfMonth: 1).toJdn()
        let endJdn = CivilDate(year: 2350, month: 1, dayOfMonth: 1).toJdn()
        for jdn in startJdn...endJdn {
            XCTAssertEqual(jdn, PersianDate(jdn: jdn).toJdn())
        }
    }

    func testIslamicCalendarConvertingToAndFromJdn() {
        let startJdn = CivilDate(year: 1750, month: 1, dayOfMonth: 1).toJdn()
        let endJdn = CivilDate(year: 2350, month: 1, dayOfMonth: 1).toJdn()
        for jdn in startJdn...endJdn {
            XCTAssertEqual(jdn, IslamicDate(jdn: jdn).toJdn())
        }
    }

    func testUmmAlQuraCalendarConvertingToAndFromJdn() {
        IslamicDate.useUmmAlQura = true
        let startJdn = CivilDate(year: 1750, month: 1, dayOfMonth: 1).toJdn()
        let endJdn = CivilDate(year: 2350, month: 1, dayOfMonth: 1).toJdn()
        for jdn in startJdn...endJdn {
            XCTAssertEqual(jdn, IslamicDate(jdn: jdn).toJdn())
        }
        IslamicDate.useUmmAlQura = false
    }

    func testGregorianCalendarConvertingToAndFromJdn() {
        let startJdn = CivilDate(year: 1750, month: 1, dayOfMonth: 1).toJdn()
        let endJdn = CivilDate(year: 2350, month: 1, dayOfMonth: 1).toJdn()
        for jdn in startJdn...endJdn {
            XCTAssertEqual(jdn, CivilDate(jdn: jdn).toJdn())
        }
    }

    /// The Kotlin test also asserts a `CivilDate` never equals a `PersianDate` with the same
    /// fields. In Swift these are distinct types, so that comparison cannot be written at all —
    /// the type system enforces statically what the Kotlin test checks at runtime.
    func testItDifferentiatesDateObjectEquality() {
        XCTAssertEqual(
            CivilDate(year: 2000, month: 1, dayOfMonth: 1),
            CivilDate(year: 2000, month: 1, dayOfMonth: 1))
        XCTAssertNotEqual(
            CivilDate(year: 2000, month: 1, dayOfMonth: 1),
            CivilDate(year: 2000, month: 2, dayOfMonth: 1))
    }

    func testPartiallyConformingWithCalendarialeTests() {
        let J0000 = 1_721_425  // Ours is different apparently

        for entry in [
            [369740, 392, 2, 5],
            [434355, 569, 1, 3],
            [470160, 667, 1, 14],
            [473837, 677, 2, 8],
            [507850, 770, 3, 22],
            [544676, 871, 1, 21],
            [601716, 1027, 3, 21],
            [613424, 1059, 4, 10],
            [626596, 1095, 5, 2],
            [645554, 1147, 3, 30],
            [664224, 1198, 5, 10],
            [671401, 1218, 1, 7],
            [694799, 1282, 1, 29],
            [704424, 1308, 6, 3],
            [708842, 1320, 7, 7],
            [709409, 1322, 1, 29],
            [709580, 1322, 7, 14],
            [727274, 1370, 12, 27],
            [728714, 1374, 12, 6],
            [744313, 1417, 8, 19],
            [764652, 1473, 4, 28],
        ] {
            XCTAssertEqual(
                entry[0] + J0000,
                PersianDate(year: entry[1], month: entry[2], dayOfMonth: entry[3]).toJdn(),
                "\(entry)")
            let from = PersianDate(jdn: entry[0] + J0000)
            XCTAssertEqual(from.year, entry[1])
            XCTAssertEqual(from.month, entry[2])
            XCTAssertEqual(from.dayOfMonth, entry[3])
        }

        for entry in [
            [2334848, 1680, 6, 30],
            [2348020, 1716, 7, 24],
            [2366978, 1768, 6, 19],
            [2385648, 1819, 8, 2],
            [2392825, 1839, 3, 27],
            [2416223, 1903, 4, 19],
            [2425848, 1929, 8, 25],
            [2430266, 1941, 9, 29],
            [2430833, 1943, 4, 19],
            [2431004, 1943, 10, 7],
            [2448698, 1992, 3, 17],
            [2450138, 1996, 2, 25],
            [2465737, 2038, 11, 10],
            [2486076, 2094, 7, 18],
        ] {
            XCTAssertEqual(
                entry[0] + 1,
                CivilDate(year: entry[1], month: entry[2], dayOfMonth: entry[3]).toJdn())
            let from = CivilDate(jdn: entry[0] + 1)
            XCTAssertEqual(from.year, entry[1])
            XCTAssertEqual(from.month, entry[2])
            XCTAssertEqual(from.dayOfMonth, entry[3])
        }

        for entry in [
            [452605, 637, 8, 7],
            [645554, 1182, 2, 4],
            [704424, 1348, 3, 19],
            [764652, 1518, 3, 5],
        ] {
            XCTAssertEqual(
                entry[0] + J0000,
                IslamicDate(year: entry[1], month: entry[2], dayOfMonth: entry[3]).toJdn(),
                "\(entry[0])")
            let from = IslamicDate(jdn: entry[0] + J0000)
            XCTAssertEqual(from.year, entry[1])
            XCTAssertEqual(from.month, entry[2])
            XCTAssertEqual(from.dayOfMonth, entry[3])
        }
    }
}
