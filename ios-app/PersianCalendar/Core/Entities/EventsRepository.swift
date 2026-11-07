import Foundation

/// Decides which events are visible, given the user's enabled holiday types, and answers day
/// queries against them.
///
/// Constructing one is not free — it filters the whole event table and configures the Islamic
/// calendar — so it is built once when settings change rather than per query.
final class EventsRepository: @unchecked Sendable {
    // Preference keys for the holiday types. Persisted, so don't change these strings.
    static let iranHolidaysKey = "iran_holidays"
    static let iranOthersKey = "iran_others"
    static let afghanistanHolidaysKey = "afghanistan_holidays"
    static let afghanistanOthersKey = "afghanistan_others"
    static let nepalHolidaysKey = "nepal_holidays"
    static let nepalOthersKey = "nepal_others"
    static let iranAncientKey = "iran_ancient"
    static let internationalKey = "international"

    static let iranDefault: Set<String> = [iranHolidaysKey]
    static let afghanistanDefault: Set<String> = [afghanistanHolidaysKey]
    static let nepalDefault: Set<String> = [nepalHolidaysKey]

    let afghanistanHolidays: Bool
    let afghanistanOthers: Bool
    let iranHolidays: Bool
    let iranAncient: Bool
    let iranOthers: Bool
    let nepalHolidays: Bool
    let nepalOthers: Bool
    let international: Bool
    let isEmpty: Bool
    let onlyIranHolidaysIsEnabled: Bool
    let onlyAfghanistanHolidaysIsEnabled: Bool

    private let enabledCalendars: [CalendarKind]
    private let currentTimeZoneIdentifier: String
    private let isAfghanistanExclusiveLanguage: Bool
    private let isIranExclusiveLanguage: Bool
    private let isPersianOrDariLanguage: Bool

    private var persianCalendarEvents = EventsStore.empty
    private var islamicCalendarEvents = EventsStore.empty
    private var gregorianCalendarEvents = EventsStore.empty
    private var nepaliCalendarEvents = EventsStore.empty
    private(set) var irregularCalendarEventsStore: IrregularCalendarEventsStore!

    /// - Parameters:
    ///   - enabledTypes: the holiday-type preference keys the user has turned on.
    ///   - enabledCalendars: calendars the user displays, which gates some Islamic events.
    ///   - mightPreferUmmAlquraIslamicCalendar: from the active language.
    init(
        enabledTypes: Set<String>,
        enabledCalendars: [CalendarKind] = [.shamsi, .gregorian, .islamic],
        numeral: Numeral = .persian,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        isIranExclusiveLanguage: Bool = true,
        isAfghanistanExclusiveLanguage: Bool = false,
        isPersianOrDariLanguage: Bool = true,
        mightPreferUmmAlquraIslamicCalendar: Bool = false
    ) {
        self.afghanistanHolidays = enabledTypes.contains(Self.afghanistanHolidaysKey)
        self.afghanistanOthers = enabledTypes.contains(Self.afghanistanOthersKey)
        self.iranHolidays = enabledTypes.contains(Self.iranHolidaysKey)
        self.iranAncient = enabledTypes.contains(Self.iranAncientKey)
        self.iranOthers = enabledTypes.contains(Self.iranOthersKey)
            || /* legacy key */ enabledTypes.contains("iran_islamic")
        self.nepalHolidays = enabledTypes.contains(Self.nepalHolidaysKey)
        self.nepalOthers = enabledTypes.contains(Self.nepalOthersKey)
        self.international = enabledTypes.contains(Self.internationalKey)
        self.isEmpty = enabledTypes.isEmpty
        self.onlyIranHolidaysIsEnabled = enabledTypes.count == 1 && iranHolidays
        self.onlyAfghanistanHolidaysIsEnabled = enabledTypes.count == 1 && afghanistanHolidays
        self.enabledCalendars = enabledCalendars
        self.currentTimeZoneIdentifier = timeZoneIdentifier
        self.isIranExclusiveLanguage = isIranExclusiveLanguage
        self.isAfghanistanExclusiveLanguage = isAfghanistanExclusiveLanguage
        self.isPersianOrDariLanguage = isPersianOrDariLanguage

        // It is vital to configure the Islamic calendar before loading the events, since the
        // event dates are resolved against whichever tabulation is active.
        IslamicDate.useUmmAlQura =
            (iranHolidays || iranOthers)
            ? false
            : (afghanistanHolidays || mightPreferUmmAlquraIslamicCalendar)

        self.irregularCalendarEventsStore = IrregularCalendarEventsStore(
            repository: self, numeral: numeral)

        let data = EventsData.shared
        self.persianCalendarEvents = EventsStore(createEvents(data.persianEvents, .shamsi))
        self.islamicCalendarEvents = EventsStore(createEvents(data.islamicEvents, .islamic))
        self.gregorianCalendarEvents = EventsStore(createEvents(data.gregorianEvents, .gregorian))
        self.nepaliCalendarEvents = EventsStore(createEvents(data.nepaliEvents, .nepali))
    }

    static func empty() -> EventsRepository { EventsRepository(enabledTypes: []) }

    // MARK: - Queries

    func events(for jdn: Jdn, deviceEvents: [CalendarEvent] = []) -> [CalendarEvent] {
        let persianDate = jdn.toPersianDate()
        let irregular = irregularCalendarEventsStore!

        let all =
            persianCalendarEvents.events(for: persianDate, irregular: irregular)
            + islamicCalendarEvents.events(for: jdn.toIslamicDate(), irregular: irregular)
            + nepaliCalendarEvents.events(for: jdn.toNepaliDate(), irregular: irregular)
            + deviceEvents.sorted { ($0.device?.start ?? .distantPast) < ($1.device?.start ?? .distantPast) }
            + gregorianCalendarEvents.events(for: jdn.toCivilDate(), irregular: irregular)

        let filtered = filterEvents(all).filter { event in
            // Iranian events without an explicit start are taken to begin in 1358.
            let begin = event.metadata.beginningPersianYear
                ?? (event.source == .iran ? 1358 : nil)
            let end = event.metadata.endingPersianYear
            switch (begin, end) {
            case let (begin?, end?): return (begin...end).contains(persianDate.year)
            case let (begin?, nil): return persianDate.year >= begin
            case let (nil, end?): return persianDate.year <= end
            case (nil, nil): return true
            }
        }

        // Holidays first, then other events, with the user's own country's events preferred.
        let isAfghanistan = isAfghanistanExclusiveLanguage
        let noPriority = !isAfghanistan && !isIranExclusiveLanguage
        return filtered.enumerated().sorted { lhs, rhs in
            let lhsKey = sortKey(lhs.element, isAfghanistan: isAfghanistan, noPriority: noPriority)
            let rhsKey = sortKey(rhs.element, isAfghanistan: isAfghanistan, noPriority: noPriority)
            // Preserve the original relative order for equal keys, as Kotlin's sortedBy does.
            return lhsKey == rhsKey ? lhs.offset < rhs.offset : lhsKey < rhsKey
        }.map(\.element)
    }

    private func sortKey(_ event: CalendarEvent, isAfghanistan: Bool, noPriority: Bool) -> Int {
        let priority = (isAfghanistan != (event.source != .afghanistan)) || noPriority
        if event.isHoliday { return priority ? 0 : 1 }
        if !event.isDeviceEvent { return priority ? 2 : 3 }
        return Int(event.device?.start.timeIntervalSince1970 ?? 0)
    }

    /// Every event that could occur in the year around `jdn`, used by the events search screen.
    func enabledEvents(around jdn: Jdn) -> [CalendarEvent] {
        let stores = [
            persianCalendarEvents, islamicCalendarEvents,
            nepaliCalendarEvents, gregorianCalendarEvents,
        ]
        let dates: [any AbstractDate] = [
            jdn.toPersianDate(), jdn.toCivilDate(), jdn.toIslamicDate(), jdn.toNepaliDate(),
        ]
        let irregular = dates.flatMap { date -> [CalendarEvent] in
            let calendar = date.calendarKind
            let thisYear = irregularCalendarEventsStore
                .eventsList(year: date.year, calendar: calendar)
                .filter { $0.month >= date.month }
            let nextYear = irregularCalendarEventsStore
                .eventsList(year: date.year + 1, calendar: calendar)
                .filter { $0.month < date.month }
            return thisYear + nextYear
        }
        return filterEvents(stores.flatMap(\.allEvents) + irregular)
    }

    /// Count of working days in `(fromJdn, toJdn]`.
    func calculateWorkDays(from fromJdn: Jdn, to toJdn: Jdn, weekEnds: Set<WeekDay>) -> Int {
        guard fromJdn < toJdn else { return 0 }
        return ((fromJdn + 1)...toJdn).count { jdn in
            !weekEnds.contains(jdn.weekDay) && !events(for: jdn).contains(where: \.isHoliday)
        }
    }

    // MARK: - Construction

    func filterEvents(_ events: [CalendarEvent]) -> [CalendarEvent] {
        events.filter { event in
            if event.metadata.alwaysDisplayed { return true }
            // Iranian Islamic-calendar events that aren't holidays are noise outside Iran.
            if !event.isHoliday && currentTimeZoneIdentifier != Self.iranTimeZoneIdentifier
                && event.source == .iran && event.calendar == .islamic
            {
                return false
            }
            return event.isHoliday
                || enabledCalendars.contains(event.calendar)
                || event.calendar != .islamic
        }
    }

    private func createEvents(
        _ records: [CalendarRecord], _ calendar: CalendarKind
    ) -> [CalendarEvent] {
        records.compactMap { record in
            guard !skipEvent(record, calendar) else { return nil }
            let prefix: String
            if record.isHoliday && record.source == .iran {
                prefix = "تعطیلی رسمی به مناسبت "
            } else if record.isHoliday && record.source == .afghanistan && isPersianOrDariLanguage {
                prefix = "رخصتی به مناسبت "
            } else {
                prefix = ""
            }
            var metadata = record.metadata
            metadata.originalTitle = record.title
            return CalendarEvent(
                title: prefix + record.title,
                isHoliday: determineIsHoliday(record),
                calendar: calendar,
                year: CalendarEvent.everyYear,
                month: record.month,
                dayOfMonth: record.day,
                source: record.source,
                metadata: metadata)
        }
    }

    private func skipEvent(_ record: CalendarRecord, _ calendar: CalendarKind) -> Bool {
        switch record.source {
        case .iran:
            if iranHolidays && record.metadata.alwaysDisplayed { return false }
            if record.isHoliday && iranHolidays { return false }
            if iranOthers { return false }
            // Iranian events on the Gregorian calendar ride along with the international set.
            if international && calendar == .gregorian { return false }
            return true
        case .iranFormer:
            if record.isHoliday && iranHolidays { return false }
            if iranOthers { return false }
            return true
        case .afghanistan:
            if afghanistanHolidays && record.metadata.alwaysDisplayed { return false }
            if record.isHoliday && afghanistanHolidays { return false }
            if afghanistanOthers { return false }
            return true
        case .nepal:
            if record.isHoliday && nepalHolidays { return false }
            if nepalOthers { return false }
            return true
        case .ancientIran:
            return !iranAncient
        case .international:
            return !international
        }
    }

    /// Don't mark holidays as holidays unless that holiday set is explicitly enabled.
    private func determineIsHoliday(_ record: CalendarRecord) -> Bool {
        switch record.source {
        case .iran where !iranHolidays: false
        case .afghanistan where !afghanistanHolidays: false
        default: record.isHoliday
        }
    }

    static let iranTimeZoneIdentifier = "Asia/Tehran"
    static let afghanistanTimeZoneIdentifier = "Asia/Kabul"
    static let nepalTimeZoneIdentifier = "Asia/Kathmandu"

    /// The holiday types to enable when the user has never chosen.
    static func defaultEnabledTypes(
        isIranExclusiveLanguage: Bool,
        isAfghanistanExclusiveLanguage: Bool,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) -> Set<String> {
        if isIranExclusiveLanguage && timeZoneIdentifier == iranTimeZoneIdentifier {
            return iranDefault
        }
        if isAfghanistanExclusiveLanguage && timeZoneIdentifier == afghanistanTimeZoneIdentifier {
            return afghanistanDefault
        }
        return []
    }

    /// Which holiday-type preference key an event belongs to.
    static func key(source: EventSource?, isHoliday: Bool) -> String? {
        switch source {
        case nil: nil
        case .ancientIran: iranAncientKey
        case .international: internationalKey
        case .iran, .iranFormer: isHoliday ? iranHolidaysKey : iranOthersKey
        case .nepal: isHoliday ? nepalHolidaysKey : nepalOthersKey
        case .afghanistan: isHoliday ? afghanistanHolidaysKey : afghanistanOthersKey
        }
    }
}
