import Foundation

/// One cell of the month grid.
struct DayCell: Hashable {
    let jdn: Jdn?
    let dayOfMonth: Int?
    let isHoliday: Bool
    let hasEvent: Bool
    let hasAppointment: Bool
    let isMoonInScorpio: Bool
    let secondaryLabel: String?
    let shiftWorkTitle: String?
    /// Pre-built VoiceOver description; nil for padding cells, which stay invisible to it.
    let accessibilityLabel: String?

    /// A blank cell, padding the grid before the first day of the month.
    static let empty = DayCell(
        jdn: nil, dayOfMonth: nil, isHoliday: false, hasEvent: false, hasAppointment: false,
        isMoonInScorpio: false, secondaryLabel: nil, shiftWorkTitle: nil,
        accessibilityLabel: nil)
}

/// The layout and contents of a single month, computed off the main actor.
struct MonthGrid {
    /// Months away from the reference month; 0 is the current month.
    let offset: Int
    let calendar: CalendarKind
    let year: Int
    let month: Int
    let title: String
    /// Column headers, starting at the user's chosen first day of the week.
    let weekDayInitials: [String]
    /// Row-major cells, always a whole number of weeks.
    let cells: [DayCell]
    /// Week-of-year numbers, one per row, when that setting is on.
    let weekNumbers: [String]

    var rowCount: Int { cells.count / 7 }

    static func build(
        offset: Int,
        today: Jdn,
        settings: Snapshot
    ) -> MonthGrid {
        let calendar = settings.mainCalendar
        let monthStart = calendar.getMonthStartFromMonthsDistance(
            baseJdn: today, monthsDistance: offset)
        let year = monthStart.year
        let month = monthStart.month
        let startJdn = Jdn(monthStart)
        let monthLength = calendar.getMonthLength(year: year, month: month)

        // Leading blanks so the first day lands under its weekday column.
        let leading = startJdn.weekDay - settings.weekStart
        var cells: [DayCell] = Array(repeating: .empty, count: leading)

        let events = settings.eventsRepository
        for day in 0..<monthLength {
            let jdn = startJdn + day
            let dayEvents = events.events(for: jdn)
            let isHoliday = dayEvents.contains(where: \.isHoliday) || settings.weekEnds.contains(jdn.weekDay)
            let secondary = settings.secondaryCalendar.map { secondary in
                settings.numeral.format(jdn.on(secondary).dayOfMonth)
            }
            let formatter = DateFormatter_(
                language: settings.language, numeral: settings.numeral)
            // Spell the day out for VoiceOver: weekday, full date, then what is on it.
            var spoken = [
                formatter.weekDayName(jdn.weekDay),
                formatter.formatDate(jdn.on(calendar), calendar: calendar),
            ]
            if isHoliday { spoken.append(settings.holidayDescription) }
            if !dayEvents.isEmpty {
                spoken.append(contentsOf: dayEvents.map(\.title))
            }

            cells.append(
                DayCell(
                    jdn: jdn,
                    dayOfMonth: day + 1,
                    isHoliday: isHoliday,
                    hasEvent: !dayEvents.isEmpty,
                    hasAppointment: dayEvents.contains(where: \.isDeviceEvent),
                    isMoonInScorpio: settings.showMoonInScorpio && isMoonInScorpio(jdn: jdn),
                    secondaryLabel: secondary,
                    shiftWorkTitle: settings.shiftWork.workTitle(
                        for: jdn, titles: settings.shiftWorkTitles, abbreviated: true),
                    accessibilityLabel: spoken.joined(separator: ", ")))
        }

        // Trailing blanks to complete the final week.
        while cells.count % 7 != 0 { cells.append(.empty) }

        var weekNumbers: [String] = []
        if settings.showWeekOfYearNumber {
            let yearStart = Jdn(calendar, year, 1, 1)
            for row in 0..<(cells.count / 7) {
                let reference = cells[(row * 7)..<((row + 1) * 7)].compactMap(\.jdn).first
                let week = (reference ?? startJdn).getWeekOfYear(
                    startOfYear: yearStart, weekStart: settings.weekStart)
                weekNumbers.append(settings.numeral.format(week))
            }
        }

        let formatter = DateFormatter_(language: settings.language, numeral: settings.numeral)
        let initials = (0..<7).map { index in
            formatter.weekDayInitial(settings.weekStart + index)
        }

        return MonthGrid(
            offset: offset,
            calendar: calendar,
            year: year,
            month: month,
            title: formatter.formatMonthYear(calendar, year: year, month: month),
            weekDayInitials: initials,
            cells: cells,
            weekNumbers: weekNumbers)
    }

    /// The subset of settings a grid build needs, captured so the work can leave the main actor.
    struct Snapshot: Sendable {
        let mainCalendar: CalendarKind
        let secondaryCalendar: CalendarKind?
        let language: AppLanguage
        let numeral: Numeral
        let weekStart: WeekDay
        let weekEnds: Set<WeekDay>
        let showWeekOfYearNumber: Bool
        let showMoonInScorpio: Bool
        let shiftWork: ShiftWorkSettings
        let shiftWorkTitles: [String: String]
        let eventsRepository: EventsRepository
        /// Localized word for "holiday", used in the spoken day description.
        let holidayDescription: String

        @MainActor
        init(_ settings: AppSettings) {
            self.mainCalendar = settings.mainCalendar
            self.secondaryCalendar =
                settings.secondaryCalendarInTable ? settings.otherCalendars.first : nil
            self.language = settings.language
            self.numeral = settings.numeral
            self.weekStart = settings.weekStart
            self.weekEnds = settings.weekEnds
            self.showWeekOfYearNumber = settings.showWeekOfYearNumber
            self.showMoonInScorpio = settings.showMoonInScorpio
            self.shiftWork = settings.shiftWork
            self.shiftWorkTitles = [:]
            self.eventsRepository = settings.eventsRepository
            self.holidayDescription =
                switch settings.language {
                case .fa: "تعطیل"
                case .ar: "عطلة"
                case .en: "holiday"
                }
        }
    }
}
