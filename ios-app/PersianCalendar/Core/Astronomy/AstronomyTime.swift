import Foundation

extension Jdn {
    /// The moment at `hourOfDay` local time on this day, as an astronomy timestamp.
    ///
    /// - Parameter setIranTime: interpret the hour in Iran's time zone rather than the device's.
    ///   Used by tests and by the "Iran time" display setting.
    func toAstronomyTime(hourOfDay: Int, setIranTime: Bool = false) -> AstroTime {
        let gregorian = toCivilDate()
        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone =
            setIranTime
            ? (TimeZone(identifier: EventsRepository.iranTimeZoneIdentifier) ?? .current)
            : .current
        var components = DateComponents()
        components.year = gregorian.year
        components.month = gregorian.month
        components.day = gregorian.dayOfMonth
        components.hour = hourOfDay
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        let date = calendar.date(from: components) ?? Date()
        return AstroTime.fromMillisecondsSince1970(Int((date.timeIntervalSince1970 * 1000).rounded()))
    }

    /// Midnight local time on this day, as a `Date`.
    func toDate(setIranTime: Bool = false) -> Date {
        toAstronomyTime(hourOfDay: 0, setIranTime: setIranTime).date
    }
}

extension Coordinates {
    var isSouthernHemisphere: Bool { latitude < 0 }

    func toObserver() -> Observer { Observer(latitude, longitude, elevation) }
}
