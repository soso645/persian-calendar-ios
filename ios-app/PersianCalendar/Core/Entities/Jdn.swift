import Foundation

/// A Julian day number — a plain day counter, used as the common currency between calendars.
///
/// https://en.wikipedia.org/wiki/Julian_day
struct Jdn: Hashable, Comparable, Strideable, Sendable {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }

    init(_ date: some AbstractDate) {
        self.value = date.toJdn()
    }

    init(_ calendar: CalendarKind, _ year: Int, _ month: Int, _ dayOfMonth: Int) {
        self.value = calendar.createDate(year: year, month: month, dayOfMonth: dayOfMonth).toJdn()
    }

    var weekDay: WeekDay {
        WeekDay(rawValue: (value + 2) % 7)!
    }

    func on(_ calendar: CalendarKind) -> any AbstractDate {
        switch calendar {
        case .islamic: toIslamicDate()
        case .gregorian: toCivilDate()
        case .shamsi: toPersianDate()
        case .nepali: toNepaliDate()
        }
    }

    func toIslamicDate() -> IslamicDate { IslamicDate(jdn: value) }
    func toCivilDate() -> CivilDate { CivilDate(jdn: value) }
    func toPersianDate() -> PersianDate { PersianDate(jdn: value) }
    func toNepaliDate() -> NepaliDate { NepaliDate(jdn: value) }

    static func < (lhs: Jdn, rhs: Jdn) -> Bool { lhs.value < rhs.value }
    static func + (lhs: Jdn, rhs: Int) -> Jdn { Jdn(lhs.value + rhs) }
    static func - (lhs: Jdn, rhs: Int) -> Jdn { Jdn(lhs.value - rhs) }
    /// Difference of two Jdn values, in days.
    static func - (lhs: Jdn, rhs: Jdn) -> Int { lhs.value - rhs.value }

    func getWeekOfYear(startOfYear: Jdn, weekStart: WeekDay) -> Int {
        let dayOfYear = self - startOfYear
        return Int(ceil(1 + Double(dayOfYear - (self.weekDay - weekStart)) / 7.0))
    }

    /// Days passed in the current season, and the total number of days in that season.
    func getPositionInSeason() -> (passedDays: Int, totalDays: Int) {
        let persianDate = toPersianDate()
        let season = (persianDate.month - 1) / 3
        let seasonBeginning = PersianDate(year: persianDate.year, month: season * 3 + 1, dayOfMonth: 1)
        let seasonBeginningJdn = Jdn(seasonBeginning)
        return (
            self - seasonBeginningJdn + 1,
            Jdn(seasonBeginning.monthStartOfMonthsDistance(3)) - seasonBeginningJdn
        )
    }

    /// Whether the Iranian Islamic calendar data covers this date's Persian year.
    var isYearSupportedOnApp: Bool {
        let delta = toPersianDate().year - supportedYearOfIranCalendar
        return delta >= -1 && delta <= 0
    }

    /// Today, from the device clock. Prefer the app-provided `today` where one is available, so
    /// the whole UI agrees on the date.
    static func today() -> Jdn {
        var utc = Foundation.Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone.current
        let parts = utc.dateComponents([.year, .month, .day], from: Date())
        return Jdn(CivilDate(year: parts.year!, month: parts.month!, dayOfMonth: parts.day!))
    }

    // Strideable, so `a...b` and `a..<b` are ordinary Swift ranges over days.
    func advanced(by n: Int) -> Jdn { Jdn(value + n) }
    func distance(to other: Jdn) -> Int { other.value - value }
}

/// The last Persian year for which the app has official Iranian Islamic calendar data.
var supportedYearOfIranCalendar: Int { IranianIslamicDateConverter.latestSupportedYearOfIran }
