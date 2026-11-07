import Foundation

/// A simple and quick implementation, just to be compatible with
/// https://calendar.ut.ac.ir/Fa/News/Data/Doc/KabiseShamsi1206-1498-new.pdf
///
/// For a correct implementation accurate for ~9k years see `CalendricalCalculations`, which
/// matches the numbers here for the IRST longitude.
enum LookupTableConverter {
    private static let startingYear = 1304

    private static let leapYears: [Int] = [
        // 1210, 1214, 1218, 1222, 1226, 1230, 1234, 1238, 1243, 1247, 1251, 1255, 1259, 1263,
        // 1267, 1271, 1276, 1280, 1284, 1288, 1292, 1296, 1300,
        1304, 1309, 1313, 1317, 1321, 1325, 1329, 1333, 1337, 1342, 1346, 1350, 1354, 1358,
        1362, 1366, 1370, 1375, 1379, 1383, 1387, 1391, 1395, 1399, 1403, 1408, 1412, 1416,
        1420, 1424, 1428, 1432, 1436, 1441, 1445, 1449, 1453, 1457, 1461, 1465, 1469, 1474,
        1478, 1482, 1486, 1490, 1494, 1498,
    ]

    /// JDN of the first day of each supported year.
    private static let yearsStartingJdn: [Int] = {
        var result = [Int](repeating: 0, count: 1498 - startingYear)
        result[0] = 2_424_231  // jdn of 1304
        var i = 0
        var j = 0
        while i < result.count - 1 {
            let year = i + startingYear
            result[i + 1] = result[i] + (leapYears[j] == year ? 366 : 365)
            if year >= leapYears[j] && j + 1 < leapYears.count { j += 1 }
            i += 1
        }
        return result
    }()

    /// Returns -1 when the year is outside the supported range.
    static func toJdn(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let table = yearsStartingJdn
        guard year >= startingYear && year <= startingYear + table.count - 1 else { return -1 }
        return table[year - startingYear] + PersianDate.daysInPreviousMonths(month) + day - 1
    }

    static func fromJdn(_ jdn: Int) -> DateTriplet? {
        let table = yearsStartingJdn
        guard jdn >= table[0] && jdn <= table[table.count - 1] else { return nil }
        var year = (jdn - table[0]) / 366
        while year < table.count - 1 {
            if jdn < table[year + 1] { break }
            year += 1
        }
        let startOfYearJdn = table[year]
        year += startingYear
        let dayOfYear = jdn - startOfYearJdn + 1
        let month = PersianDate.monthFromDaysCount(dayOfYear)
        let day = dayOfYear - PersianDate.daysInPreviousMonths(month)
        return DateTriplet(year: year, month: month, dayOfMonth: day)
    }
}
