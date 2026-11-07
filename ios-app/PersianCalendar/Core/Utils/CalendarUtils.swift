import Foundation

/// The difference between two dates broken into whole years, months and days.
///
/// Both dates must be in `calendar`. Mirrors `utils/CalendarUtils.kt`.
func calculateDatePartsDifference(
    from fromDate: any AbstractDate,
    to toDate: any AbstractDate,
    calendar: CalendarKind
) -> (years: Int, months: Int, days: Int) {
    var y = toDate.year - fromDate.year
    var m = toDate.month - fromDate.month
    var d = toDate.dayOfMonth - fromDate.dayOfMonth
    if d < 0 {
        m -= 1
        d += calendar.getMonthLength(year: fromDate.year, month: fromDate.month)
    }
    if m < 0 {
        y -= 1
        m += calendar.getYearMonths(year: fromDate.year)
    }
    return (y, m, d)
}
