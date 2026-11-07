import Foundation

/// Events indexed by day-of-year position, for constant-time lookup while drawing the month grid.
struct EventsStore: Sendable {
    /// Month and day of month packed into one key. Year is checked after lookup, since annually
    /// recurring events use ``CalendarEvent/everyYear``.
    static func hash(_ date: any AbstractDate) -> Int { date.month * 100 + date.dayOfMonth }
    static func hash(month: Int, dayOfMonth: Int) -> Int { month * 100 + dayOfMonth }

    private let store: [Int: [CalendarEvent]]

    init(_ events: [CalendarEvent]) {
        self.store = Dictionary(
            grouping: events, by: { Self.hash(month: $0.month, dayOfMonth: $0.dayOfMonth) })
    }

    static let empty = EventsStore([])

    /// Events on exactly this date, ignoring irregular rules.
    func entry(for date: any AbstractDate) -> [CalendarEvent] {
        store[Self.hash(date)]?.filter {
            // Month and day are already matched by the key, so only the year is left to check.
            $0.year == date.year || $0.year == CalendarEvent.everyYear
        } ?? []
    }

    func events(
        for date: any AbstractDate, irregular: IrregularCalendarEventsStore
    ) -> [CalendarEvent] {
        entry(for: date) + irregular.events(for: date)
    }

    var allEvents: [CalendarEvent] { store.values.flatMap { $0 } }
}
