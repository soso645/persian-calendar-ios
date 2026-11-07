import Foundation

/// Days of the week, ordered Saturday-first.
///
/// This ordering is a legacy of the Android codebase and **differs from ISO-8601** — it is not
/// 1 (Monday) through 7 (Sunday). Persisted values and JDN arithmetic depend on it, so it must not
/// be "corrected".
enum WeekDay: Int, CaseIterable, Sendable {
    case saturday = 0
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday

    /// Days from `other` forward to `self`, in [0, 7).
    static func - (lhs: WeekDay, rhs: WeekDay) -> Int {
        (lhs.rawValue + 7 - rhs.rawValue) % 7
    }

    static func + (lhs: WeekDay, rhs: Int) -> WeekDay {
        WeekDay(rawValue: (lhs.rawValue + rhs) % 7)!
    }

    /// Build from an ISO-8601 ordinal, 1 (Monday) through 7 (Sunday).
    static func fromISO8601(_ value: Int) -> WeekDay {
        WeekDay(rawValue: value % 7)!
    }
}
