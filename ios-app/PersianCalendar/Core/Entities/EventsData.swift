import Foundation

/// One row of `events.json` that recurs on a fixed month/day.
struct CalendarRecord: Sendable {
    let title: String
    let source: EventSource
    let isHoliday: Bool
    let month: Int
    let day: Int
    let metadata: EventMetadata
}

/// One row of `events.json` whose date has to be computed per year.
struct IrregularEventRecord: Sendable {
    enum Rule: String, Sendable {
        case singleEvent = "single event"
        case nthDayFrom = "nth day from"
        case endOfMonth = "end of month"
        case lastWeekdayOfMonth = "last weekday of month"
        case nthWeekdayOfMonth = "nth weekday of month"
    }

    let title: String
    let source: EventSource
    let isHoliday: Bool
    let calendar: CalendarKind
    let rule: Rule
    let month: Int
    let day: Int?
    let year: Int?
    let nth: Int?
    /// ISO-8601 weekday, 1 (Monday) to 7 (Sunday).
    let weekday: Int?
    let offset: Int
    let metadata: EventMetadata
}

/// The parsed contents of the bundled `events.json`.
///
/// The Android build generates Kotlin source from this file at compile time via a Gradle codegen
/// task. Doing it at runtime instead keeps the data file as the single source of truth — updating
/// the app's events is then a matter of dropping in a newer `events.json`.
struct EventsData: Sendable {
    let persianEvents: [CalendarRecord]
    let islamicEvents: [CalendarRecord]
    let gregorianEvents: [CalendarRecord]
    let nepaliEvents: [CalendarRecord]
    let irregularRecurringEvents: [IrregularEventRecord]
    /// Reference URL per source, from the file's `Source` object.
    let sourceLinks: [EventSource: String]

    static let shared: EventsData = {
        guard let url = Bundle.main.url(forResource: "events", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            preconditionFailure("events.json is missing from the app bundle")
        }
        do {
            return try EventsData(data: data)
        } catch {
            preconditionFailure("events.json could not be parsed: \(error)")
        }
    }()

    init(data: Data) throws {
        let root = try JSONDecoder().decode(RawRoot.self, from: data)

        var links: [EventSource: String] = [:]
        for (key, value) in root.source {
            if let source = EventSource(rawValue: key) { links[source] = value }
        }
        self.sourceLinks = links

        var persian: [CalendarRecord] = []
        var islamic: [CalendarRecord] = []
        var gregorian: [CalendarRecord] = []
        var nepali: [CalendarRecord] = []
        var irregular: [IrregularEventRecord] = []

        for raw in root.data {
            guard let source = EventSource(rawValue: raw.type) else { continue }
            guard let calendar = Self.calendar(for: raw.calendar) else { continue }
            let metadata = raw.metadata?.toEventMetadata() ?? .empty

            if raw.rule == "simple" {
                guard let day = raw.day else { continue }
                let record = CalendarRecord(
                    title: raw.title,
                    source: source,
                    isHoliday: raw.holiday,
                    month: raw.month,
                    day: day,
                    metadata: metadata)
                switch calendar {
                case .shamsi: persian.append(record)
                case .islamic: islamic.append(record)
                case .gregorian: gregorian.append(record)
                case .nepali: nepali.append(record)
                }
            } else {
                guard let rule = IrregularEventRecord.Rule(rawValue: raw.rule) else { continue }
                irregular.append(
                    IrregularEventRecord(
                        title: raw.title,
                        source: source,
                        isHoliday: raw.holiday,
                        calendar: calendar,
                        rule: rule,
                        month: raw.month,
                        day: raw.day,
                        year: raw.year,
                        nth: raw.nth,
                        weekday: raw.weekday,
                        offset: raw.offset ?? 0,
                        metadata: metadata))
            }
        }

        self.persianEvents = persian
        self.islamicEvents = islamic
        self.gregorianEvents = gregorian
        self.nepaliEvents = nepali
        self.irregularRecurringEvents = irregular
    }

    private static func calendar(for name: String) -> CalendarKind? {
        switch name {
        case "Persian": .shamsi
        case "Hijri": .islamic
        case "Gregorian": .gregorian
        case "Nepali": .nepali
        default: nil
        }
    }

    // MARK: - JSON shapes

    private struct RawRoot: Decodable {
        let source: [String: String]
        let data: [RawEvent]

        enum CodingKeys: String, CodingKey {
            case source = "Source"
            case data
        }
    }

    private struct RawEvent: Decodable {
        let holiday: Bool
        let month: Int
        let day: Int?
        let year: Int?
        let type: String
        let title: String
        let calendar: String
        let rule: String
        let nth: Int?
        let weekday: Int?
        let offset: Int?
        let metadata: RawMetadata?
    }

    private struct RawMetadata: Decodable {
        let wikipedia: String?
        let alwaysDisplayed: Bool?
        let beginningPersianYear: Int?
        let beginningPersianYearReference: String?
        let endingPersianYear: Int?
        let endingPersianYearReference: String?
        let alias: String?

        func toEventMetadata() -> EventMetadata {
            EventMetadata(
                originalTitle: nil,
                wikipedia: wikipedia,
                alwaysDisplayed: alwaysDisplayed ?? false,
                beginningPersianYear: beginningPersianYear,
                beginningPersianYearReference: beginningPersianYearReference,
                endingPersianYear: endingPersianYear,
                endingPersianYearReference: endingPersianYearReference,
                alias: alias)
        }
    }
}
