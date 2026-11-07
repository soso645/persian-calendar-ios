import Foundation

/// A date in some calendar system, convertible to and from a Julian Day Number.
///
/// From https://en.wikipedia.org/wiki/Julian_day: the Julian day is a continuous count of days,
/// which makes converting between calendar systems a matter of routing through a single integer.
///
/// The Kotlin original is an abstract class; here it is a protocol implemented by four structs.
protocol AbstractDate: Hashable, Sendable, CustomStringConvertible {
    var year: Int { get }
    var month: Int { get }
    var dayOfMonth: Int { get }

    init(year: Int, month: Int, dayOfMonth: Int)
    init(jdn: Int)

    func toJdn() -> Int
    static func fromJdn(_ jdn: Int) -> DateTriplet
}

extension AbstractDate {
    init(triplet: DateTriplet) {
        self.init(year: triplet.year, month: triplet.month, dayOfMonth: triplet.dayOfMonth)
    }

    /// Convert from any other calendar system.
    init(_ other: some AbstractDate) {
        self.init(jdn: other.toJdn())
    }

    var triplet: DateTriplet {
        DateTriplet(year: year, month: month, dayOfMonth: dayOfMonth)
    }
}

// MARK: - Twelve-month year arithmetic

/// All four supported calendars have exactly twelve months per year, so month arithmetic is shared.
/// Mirrors `util/TwelveMonthsYear.kt`.
extension AbstractDate {
    /// The first day of the month `monthsDistance` months away from this date's month.
    func monthStartOfMonthsDistance(_ monthsDistance: Int) -> Self {
        // Make the month zero-based for easier calculations
        var month = monthsDistance + self.month - 1
        var year = self.year + (month / 12)
        month %= 12
        if month < 0 {
            year -= 1
            month += 12
        }
        return Self(year: year, month: month + 1, dayOfMonth: 1)
    }

    /// How many months separate this date's month from `date`'s month.
    func monthsDistance(to date: Self) -> Int {
        ((date.year - year) * 12) + date.month - month
    }
}
