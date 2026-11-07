import XCTest
@testable import PersianCalendar

/// Mirrors the calendar-entity portions of
/// `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/CalendarTests.kt`.
final class CalendarTests: XCTestCase {

    func testGetMonthLengthCalculatingCorrectness() {
        let expected = [
            (1397, 1, 31), (1397, 2, 31), (1397, 3, 31), (1397, 4, 31),
            (1397, 5, 31), (1397, 6, 31), (1397, 7, 30), (1397, 8, 30),
            (1397, 9, 30), (1397, 10, 30), (1397, 11, 30), (1397, 12, 29),
        ]
        for (year, month, length) in expected {
            XCTAssertEqual(
                CalendarKind.shamsi.getMonthLength(year: year, month: month), length,
                "\(year)/\(month)")
        }
    }

    func testLeapYearsCorrectness() {
        // Matches https://calendar.ut.ac.ir/Fa/News/Data/Doc/KabiseShamsi1206-1498-new.pdf
        let leapYears: Set<Int> = [
            1210, 1214, 1218, 1222, 1226, 1230, 1234, 1238, 1243, 1247, 1251, 1255, 1259, 1263,
            1267, 1271, 1276, 1280, 1284, 1288, 1292, 1296, 1300, 1304, 1309, 1313, 1317, 1321,
            1325, 1329, 1333, 1337, 1342, 1346, 1350, 1354, 1358, 1362, 1366, 1370, 1375, 1379,
            1383, 1387, 1391, 1395, 1399, 1403, 1408, 1412, 1416, 1420, 1424, 1428, 1432, 1436,
            1441, 1445, 1449, 1453, 1457, 1461, 1465, 1469, 1474, 1478, 1482, 1486, 1490, 1494,
            1498,
        ]

        for year in 1206...1498 {
            XCTAssertEqual(
                leapYears.contains(year) ? 366 : 365,
                Jdn(PersianDate(year: year + 1, month: 1, dayOfMonth: 1))
                    - Jdn(PersianDate(year: year, month: 1, dayOfMonth: 1)),
                "\(year)")
            if year > 1303 {
                XCTAssertEqual(
                    leapYears.contains(year) ? 30 : 29,
                    CalendarKind.shamsi.getMonthLength(year: year, month: 12),
                    "\(year)")
            }
        }
    }

    func testWeekDayCalculationsCorrectness() {
        let cases = [
            (0, 1398, 9, 9), (1, 1398, 9, 10), (2, 1398, 9, 11), (3, 1398, 9, 12),
            (4, 1398, 9, 13), (5, 1398, 9, 14), (6, 1398, 9, 15), (0, 1398, 9, 16),
            (1, 1398, 9, 17), (2, 1398, 9, 18), (3, 1398, 9, 19), (4, 1398, 9, 20),
            (5, 1398, 9, 21), (6, 1398, 9, 22),
        ]
        for (weekDay, year, month, dayOfMonth) in cases {
            XCTAssertEqual(
                weekDay,
                Jdn(PersianDate(year: year, month: month, dayOfMonth: dayOfMonth)).weekDay.rawValue,
                "\(year)/\(month)/\(dayOfMonth)")
        }
    }

    func testDatePartsDifference() {
        let cases = [
            (1363, 3, 19, 1400, 11, 15, 37, 7, 27),
            (1400, 6, 31, 1400, 8, 1, 0, 1, 1),
            (1363, 11, 15, 1400, 11, 15, 37, 0, 0),
            (1363, 11, 14, 1400, 11, 15, 37, 0, 1),
            (1363, 11, 16, 1400, 11, 15, 36, 11, 29),
            (1400, 7, 15, 1400, 11, 15, 0, 4, 0),
            (1400, 8, 15, 1400, 11, 15, 0, 3, 0),
            (1400, 9, 15, 1400, 11, 15, 0, 2, 0),
            (1400, 10, 15, 1400, 11, 15, 0, 1, 0),
            // Adopted from the Shahid Sadoughi University age-calculation document, except we
            // don't get the same result there.
            (1360, 5, 20, 1379, 6, 10, 19, 0, 21),
            (1360, 5, 20, 1360, 6, 10, 0, 0, 21),
        ]
        for (fy, fm, fd, ty, tm, td, year, month, day) in cases {
            let lower = PersianDate(year: fy, month: fm, dayOfMonth: fd)
            let higher = PersianDate(year: ty, month: tm, dayOfMonth: td)
            let result = calculateDatePartsDifference(from: lower, to: higher, calendar: .shamsi)
            let label = "\(fy)/\(fm)/\(fd) -> \(ty)/\(tm)/\(td)"
            XCTAssertEqual(result.days, day, "\(label) days")
            XCTAssertEqual(result.months, month, "\(label) months")
            XCTAssertEqual(result.years, year, "\(label) years")
        }
    }

    func testSeasonPassedDays() {
        let cases = [
            (1400, 12, 15, 75, 89),
            (1400, 10, 1, 1, 89),
            (1400, 12, 29, 89, 89),
            (1399, 12, 30, 90, 90),
            (1399, 9, 30, 90, 90),
            (1399, 8, 30, 60, 90),
            (1399, 7, 30, 30, 90),
            (1399, 6, 31, 93, 93),
            (1399, 4, 1, 1, 93),
            (1399, 3, 31, 93, 93),
        ]
        for (year, month, day, passedDays, daysCount) in cases {
            let jdn = Jdn(.shamsi, year, month, day)
            let position = jdn.getPositionInSeason()
            let label = "\(year)/\(month)/\(day)"
            XCTAssertEqual(position.passedDays, passedDays, "\(label) passed")
            XCTAssertEqual(position.totalDays, daysCount, "\(label) total")
        }
    }
}
