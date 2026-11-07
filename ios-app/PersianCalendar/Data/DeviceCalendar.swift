import EventKit
import Foundation

/// Reads the user's own calendar events so they can appear alongside the built-in ones.
///
/// Replaces the Android app's `CalendarContract` queries. Access is read-only and only requested
/// when the user turns the feature on.
@MainActor
@Observable
final class DeviceCalendarStore {
    enum Access: Equatable {
        case notDetermined
        case granted
        case denied
    }

    private(set) var access: Access = .notDetermined

    private let store = EKEventStore()
    /// Events keyed by JDN, for the currently loaded window.
    private var cache: [Int: [CalendarEvent]] = [:]
    private var loadedRange: ClosedRange<Int>?

    init() {
        access = Self.access(for: EKEventStore.authorizationStatus(for: .event))
    }

    private static func access(for status: EKAuthorizationStatus) -> Access {
        switch status {
        case .fullAccess, .authorized: .granted
        case .denied, .restricted, .writeOnly: .denied
        default: .notDetermined
        }
    }

    /// Ask for read access. Safe to call repeatedly; returns the resulting state.
    @discardableResult
    func requestAccess() async -> Access {
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .granted : .denied
        } catch {
            access = .denied
        }
        return access
    }

    /// Events for one day, from whatever window is currently loaded.
    func events(for jdn: Jdn) -> [CalendarEvent] {
        cache[jdn.value] ?? []
    }

    /// Load a window of days into the cache. Re-loading the same range is a no-op.
    func load(from start: Jdn, to end: Jdn, formatter: DateFormatter_) {
        guard access == .granted else { return }
        let range = start.value...end.value
        if let loadedRange, loadedRange == range { return }

        let startDate = start.toDate()
        // EventKit's end bound is exclusive of the following midnight, so add a day.
        let endDate = (end + 1).toDate()
        let predicate = store.predicateForEvents(
            withStart: startDate, end: endDate, calendars: nil)

        var result: [Int: [CalendarEvent]] = [:]
        for ekEvent in store.events(matching: predicate) {
            guard let eventStart = ekEvent.startDate else { continue }
            let jdn = Self.jdn(for: eventStart)
            let civil = jdn.toCivilDate()
            let time: String? = ekEvent.isAllDay
                ? nil
                : formatter.formatClock(Self.clock(for: eventStart))
            let event = CalendarEvent(
                title: ekEvent.title ?? "",
                isHoliday: false,
                calendar: .gregorian,
                year: civil.year,
                month: civil.month,
                dayOfMonth: civil.dayOfMonth,
                source: nil,
                metadata: .empty,
                device: DeviceEvent(
                    id: ekEvent.eventIdentifier ?? UUID().uuidString,
                    description: ekEvent.notes ?? "",
                    start: eventStart,
                    end: ekEvent.endDate ?? eventStart,
                    color: ekEvent.calendar?.cgColor.map { "\($0)" } ?? "",
                    time: time))
            result[jdn.value, default: []].append(event)
        }

        cache = result
        loadedRange = range
    }

    private static func jdn(for date: Date) -> Jdn {
        let parts = Foundation.Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: date)
        return Jdn(
            CivilDate(year: parts.year!, month: parts.month!, dayOfMonth: parts.day!))
    }

    private static func clock(for date: Date) -> Clock {
        let parts = Foundation.Calendar(identifier: .gregorian)
            .dateComponents([.hour, .minute], from: date)
        return Clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}
