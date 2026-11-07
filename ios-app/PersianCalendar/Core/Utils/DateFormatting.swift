import Foundation

/// Date formatting for display, replacing the parts of `utils/CalendarUtils.kt` and `Language.kt`
/// that produce user-facing date strings.
struct DateFormatter_ {
    let language: AppLanguage
    let numeral: Numeral

    init(language: AppLanguage, numeral: Numeral) {
        self.language = language
        self.numeral = numeral
    }

    func monthName(_ calendar: CalendarKind, _ month: Int) -> String {
        let months = CalendarNames.months(for: calendar, language: language)
        guard (1...months.count).contains(month) else { return "" }
        return months[month - 1]
    }

    /// "۱ فروردین ۱۴۰۳"
    func formatDate(
        _ date: any AbstractDate, calendar: CalendarKind,
        forceNonNumerical: Bool = false, numericalPreferred: Bool = false
    ) -> String {
        if numericalPreferred && !forceNonNumerical {
            return formatNumericalDate(date)
        }
        let day = numeral.format(date.dayOfMonth)
        let month = monthName(calendar, date.month)
        let year = numeral.format(date.year)
        return language.isRTL ? "\(day) \(month) \(year)" : "\(day) \(month) \(year)"
    }

    /// "۱۴۰۳/۱/۱", or ISO-8601 order when that setting is on.
    func formatNumericalDate(_ date: any AbstractDate, iso8601: Bool = false) -> String {
        let parts =
            iso8601
            ? [
                String(format: "%04d", date.year),
                String(format: "%02d", date.month),
                String(format: "%02d", date.dayOfMonth),
            ]
            : ["\(date.year)", "\(date.month)", "\(date.dayOfMonth)"]
        return numeral.format(parts.joined(separator: "/"))
    }

    /// "فروردین ۱۴۰۳"
    func formatMonthYear(_ calendar: CalendarKind, year: Int, month: Int) -> String {
        "\(monthName(calendar, month)) \(numeral.format(year))"
    }

    func weekDayName(_ weekDay: WeekDay) -> String {
        CalendarNames.weekDays(language)[weekDay.rawValue]
    }

    func weekDayInitial(_ weekDay: WeekDay) -> String {
        CalendarNames.weekDaysInitials(language)[weekDay.rawValue]
    }

    /// "شنبه ۱ فروردین ۱۴۰۳"
    func formatFullDate(_ jdn: Jdn, calendar: CalendarKind) -> String {
        "\(weekDayName(jdn.weekDay)) \(formatDate(jdn.on(calendar), calendar: calendar))"
    }

    /// Clock time, honouring the 12/24-hour preference of the locale.
    func formatClock(_ clock: Clock, in24: Bool = true, showAmPm: Bool = true) -> String {
        let (hours, minutes) = clock.toHoursAndMinutesPair()
        if in24 {
            return numeral.format(String(format: "%d:%02d", hours, minutes))
        }
        let displayHours = hours % 12 == 0 ? 12 : hours % 12
        let text = numeral.format(String(format: "%d:%02d", displayHours, minutes))
        guard showAmPm else { return text }
        return "\(text) \(hours >= 12 ? pmString : amString)"
    }

    var amString: String {
        switch language {
        case .fa: "ق.ظ"
        case .ar: "ص"
        case .en: "AM"
        }
    }

    var pmString: String {
        switch language {
        case .fa: "ب.ظ"
        case .ar: "م"
        case .en: "PM"
        }
    }

    var spacedComma: String { language.isRTL ? "، " : ", " }
    var spacedColon: String { language.isRTL ? ": " : ": " }
}
