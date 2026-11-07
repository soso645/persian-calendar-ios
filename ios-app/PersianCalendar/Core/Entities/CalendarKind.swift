import Foundation

/// The calendar systems the app can display.
///
/// Named `CalendarKind` rather than `Calendar` to avoid colliding with `Foundation.Calendar`.
/// The Kotlin original calls this `Calendar`; the raw values must not change, as they are
/// persisted in preferences.
enum CalendarKind: String, CaseIterable, Sendable {
    // So vital, don't ever change the raw values of these
    case shamsi = "SHAMSI"
    case islamic = "ISLAMIC"
    case gregorian = "GREGORIAN"
    case nepali = "NEPALI"

    var preferredNumeral: Numeral {
        switch self {
        case .shamsi: .persian
        case .islamic: .arabicIndic
        case .gregorian: .arabic
        case .nepali: .devanagari
        }
    }

    func createDate(year: Int, month: Int, dayOfMonth: Int) -> any AbstractDate {
        switch self {
        case .islamic: IslamicDate(year: year, month: month, dayOfMonth: dayOfMonth)
        case .gregorian: CivilDate(year: year, month: month, dayOfMonth: dayOfMonth)
        case .shamsi: PersianDate(year: year, month: month, dayOfMonth: dayOfMonth)
        case .nepali: NepaliDate(year: year, month: month, dayOfMonth: dayOfMonth)
        }
    }

    /// The day of month of the `nth` occurrence of an ISO-8601 `weekDay` in the given month.
    func getNthWeekDayOfMonth(year: Int, month: Int, weekDay: Int, nth: Int) -> Int {
        let appWeekDay = WeekDay.fromISO8601(weekDay).rawValue
        let monthStartWeekDay = Jdn(self, year, month, 1).weekDay.rawValue
        return appWeekDay + 1 - monthStartWeekDay + nth * 7
            - (monthStartWeekDay <= appWeekDay ? 7 : 0)
    }

    /// The day of month of the last ISO-8601 `weekDay` in the given month.
    func getLastWeekDayOfMonth(year: Int, month: Int, weekDay: Int) -> Int {
        let appWeekDay = WeekDay.fromISO8601(weekDay).rawValue
        let monthLength = getMonthLength(year: year, month: month)
        return monthLength - (Jdn(self, year, month, monthLength) - appWeekDay).weekDay.rawValue
    }

    /// How many months the given year has. Twelve for every calendar here, computed rather than
    /// assumed, as in the original.
    func getYearMonths(year: Int) -> Int {
        (Jdn(self, year + 1, 1, 1) - 1).on(self).month
    }

    func getMonthLength(year: Int, month: Int) -> Int {
        let nextMonthStart = getMonthStartFromMonthsDistance(
            baseYear: year, baseMonth: month, monthsDistance: 1)
        return (Jdn(nextMonthStart) - 1).on(self).dayOfMonth
    }

    private func getMonthStartFromMonthsDistance(
        baseYear: Int, baseMonth: Int, monthsDistance: Int
    ) -> any AbstractDate {
        switch self {
        case .islamic:
            IslamicDate(year: baseYear, month: baseMonth, dayOfMonth: 1)
                .monthStartOfMonthsDistance(monthsDistance)
        case .gregorian:
            CivilDate(year: baseYear, month: baseMonth, dayOfMonth: 1)
                .monthStartOfMonthsDistance(monthsDistance)
        case .shamsi:
            PersianDate(year: baseYear, month: baseMonth, dayOfMonth: 1)
                .monthStartOfMonthsDistance(monthsDistance)
        case .nepali:
            NepaliDate(year: baseYear, month: baseMonth, dayOfMonth: 1)
                .monthStartOfMonthsDistance(monthsDistance)
        }
    }

    func getMonthsDistance(from baseJdn: Jdn, to toJdn: Jdn) -> Int {
        switch self {
        case .islamic:
            baseJdn.toIslamicDate().monthsDistance(to: toJdn.toIslamicDate())
        case .gregorian:
            baseJdn.toCivilDate().monthsDistance(to: toJdn.toCivilDate())
        case .shamsi:
            baseJdn.toPersianDate().monthsDistance(to: toJdn.toPersianDate())
        case .nepali:
            baseJdn.toNepaliDate().monthsDistance(to: toJdn.toNepaliDate())
        }
    }

    func getMonthStartFromMonthsDistance(baseJdn: Jdn, monthsDistance: Int) -> any AbstractDate {
        let date = baseJdn.on(self)
        return getMonthStartFromMonthsDistance(
            baseYear: date.year, baseMonth: date.month, monthsDistance: monthsDistance)
    }
}
