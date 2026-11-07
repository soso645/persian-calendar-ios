import Foundation

/// Where an event's data came from, and therefore which holiday setting governs it.
///
/// These match the keys of the `Source` object in `events.json`.
enum EventSource: String, CaseIterable, Sendable {
    case afghanistan = "Afghanistan"
    case iran = "Iran"
    case iranFormer = "IranFormer"
    case ancientIran = "AncientIran"
    case international = "International"
    case nepal = "Nepal"
}

/// Extra facts attached to an event.
///
/// The Kotlin original carries an untyped `Map<String, Any>`. Every key that actually occurs in
/// `events.json` is spelled out here instead, which makes the type `Hashable` and `Sendable` and
/// removes a class of lookup typos.
struct EventMetadata: Hashable, Sendable {
    /// The event's title before any "official holiday for the occasion of" prefix is applied.
    var originalTitle: String?
    var wikipedia: String?
    /// Show this event even when its calendar or source would otherwise be filtered out.
    var alwaysDisplayed: Bool = false
    /// First Persian year the event applies to.
    var beginningPersianYear: Int?
    var beginningPersianYearReference: String?
    /// Last Persian year the event applies to.
    var endingPersianYear: Int?
    var endingPersianYearReference: String?
    /// An alternative name the event is also known by.
    var alias: String?

    static let empty = EventMetadata()
}

/// An event from the device's own calendar database (EventKit).
struct DeviceEvent: Hashable, Sendable {
    let id: String
    let description: String
    let start: Date
    let end: Date
    let color: String
    /// A pre-formatted time range, or nil for all-day events.
    let time: String?
}

/// A dated event.
///
/// The Kotlin original is a sealed class with one subclass per calendar, each holding a typed
/// `AbstractDate`. Here the date is flattened into `calendar` plus year/month/day: it is the same
/// information, it keeps the type concrete (so `Hashable`, `Sendable` and fast dictionary keys all
/// come for free), and it avoids boxing an existential for every event on every day of the grid.
struct CalendarEvent: Hashable, Sendable {
    /// A year of ``everyYear`` means the event recurs annually.
    static let everyYear = -1

    let title: String
    let isHoliday: Bool
    let calendar: CalendarKind
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let source: EventSource?
    var metadata: EventMetadata = .empty
    /// Set only on the Nowruz equinox pseudo-event, which carries a countdown.
    var equinoxRemainingMillis: Int?
    /// Set only on events read from the device calendar.
    var device: DeviceEvent?

    var isDeviceEvent: Bool { device != nil }

    /// True when this event occurs on `date`, accounting for annually recurring events.
    func matches(_ date: any AbstractDate, in calendar: CalendarKind) -> Bool {
        self.calendar == calendar
            && month == date.month
            && dayOfMonth == date.dayOfMonth
            && (year == date.year || year == Self.everyYear)
    }
}
