import Foundation

/// Resolves the events whose dates follow a rule rather than a fixed month/day, per year.
///
/// Results are memoized per (calendar, year) because the month grid asks for the same year
/// repeatedly while scrolling.
final class IrregularCalendarEventsStore: @unchecked Sendable {
    private let repository: EventsRepository
    private let numeral: Numeral
    private let lock = NSLock()
    private var cache: [CacheKey: [CalendarEvent]] = [:]

    private struct CacheKey: Hashable {
        let calendar: CalendarKind
        let year: Int
    }

    init(repository: EventsRepository, numeral: Numeral) {
        self.repository = repository
        self.numeral = numeral
    }

    func eventsList(year: Int, calendar: CalendarKind) -> [CalendarEvent] {
        let key = CacheKey(calendar: calendar, year: year)
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let generated = generateEntry(year: year, calendar: calendar)
        // Bound the cache the way the Kotlin LruCache(32) does, without tracking recency: the
        // access pattern is a sliding window of nearby years, so a wholesale drop is fine.
        if cache.count >= 32 { cache.removeAll(keepingCapacity: true) }
        cache[key] = generated
        return generated
    }

    func events(for date: any AbstractDate) -> [CalendarEvent] {
        let calendar = date.calendarKind
        return eventsList(year: date.year, calendar: calendar).filter {
            $0.year == date.year && $0.month == date.month && $0.dayOfMonth == date.dayOfMonth
        }
    }

    /// Build the year's irregular events from the rules, filtered by the enabled holiday types.
    private func generateEntry(year: Int, calendar: CalendarKind) -> [CalendarEvent] {
        EventsData.shared.irregularRecurringEvents.compactMap { event -> CalendarEvent? in
            guard event.calendar == calendar else { return nil }
            guard isEnabled(event) else { return nil }
            guard let date = Self.dateInstance(for: event, year: year, calendar: calendar) else {
                return nil
            }
            var metadata = event.metadata
            metadata.originalTitle = event.title
            return CalendarEvent(
                title: "\(event.title) (\(numeral.format(year)))",
                isHoliday: event.isHoliday,
                calendar: calendar,
                year: date.year,
                month: date.month,
                dayOfMonth: date.dayOfMonth,
                source: event.source,
                metadata: metadata)
        }
    }

    private func isEnabled(_ event: IrregularEventRecord) -> Bool {
        switch event.source {
        case .international: repository.international
        case .iran: (repository.iranHolidays && event.isHoliday) || repository.iranOthers
        case .afghanistan:
            (repository.afghanistanHolidays && event.isHoliday) || repository.afghanistanOthers
        case .nepal: (repository.nepalHolidays && event.isHoliday) || repository.nepalOthers
        case .ancientIran: repository.iranAncient
        case .iranFormer: false
        }
    }

    /// Apply an event's recurrence rule to a specific year.
    static func dateInstance(
        for event: IrregularEventRecord, year: Int, calendar: CalendarKind
    ) -> (any AbstractDate)? {
        switch event.rule {
        case .singleEvent:
            guard event.year == year, let day = event.day else { return nil }
            return calendar.createDate(year: year, month: event.month, dayOfMonth: day)

        case .nthDayFrom:
            guard let nth = event.nth, let day = event.day else { return nil }
            return (Jdn(calendar, year, event.month, day) + nth - 1).on(calendar)

        case .endOfMonth:
            let length = calendar.getMonthLength(year: year, month: event.month)
            return calendar.createDate(year: year, month: event.month, dayOfMonth: length)

        case .lastWeekdayOfMonth:
            guard let weekday = event.weekday else { return nil }
            let day = calendar.getLastWeekDayOfMonth(
                year: year, month: event.month, weekDay: weekday)
            return calendar.createDate(
                year: year, month: event.month, dayOfMonth: day + event.offset)

        case .nthWeekdayOfMonth:
            guard let weekday = event.weekday, let nth = event.nth else { return nil }
            let day = calendar.getNthWeekDayOfMonth(
                year: year, month: event.month, weekDay: weekday, nth: nth)
            return calendar.createDate(year: year, month: event.month, dayOfMonth: day)
        }
    }
}

extension AbstractDate {
    /// Which calendar system this date belongs to.
    var calendarKind: CalendarKind {
        switch self {
        case is PersianDate: .shamsi
        case is IslamicDate: .islamic
        case is CivilDate: .gregorian
        case is NepaliDate: .nepali
        default: preconditionFailure("unknown calendar for \(type(of: self))")
        }
    }
}
