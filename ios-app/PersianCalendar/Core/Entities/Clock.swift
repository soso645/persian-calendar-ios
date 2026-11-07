import Foundation

/// A time of day as a real number, usually in [0-24) — a portion of a day.
///
/// Only the framework-independent parts are ported here. The localized formatting methods
/// (`toFormattedString`, `asRemainingTime`) depend on app settings and language, and arrive with
/// the settings layer.
struct Clock: Hashable, Comparable, Sendable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    /// Construct from a wall-clock time's hour/minute/second/nanosecond components.
    init(hour: Int, minute: Int, second: Int = 0, nanosecond: Int = 0) {
        self.value = Double(hour)
            + Double(minute) / 60
            + Double(second) / 3600
            + Double(nanosecond) / 3_600_000_000_000
    }

    func toMillis() -> Int {
        value.isNaN ? 0 : Int(value * 3_600_000)
    }

    /// Truncated hours and minutes. NaN becomes (0, 0), as in the original.
    func toHoursAndMinutesPair() -> (hours: Int, minutes: Int) {
        if value.isNaN { return (0, 0) }
        let hours = Int(value)
        let minutes = Int((value - Double(hours)) * 60)
        return (hours, minutes)
    }

    static func < (lhs: Clock, rhs: Clock) -> Bool { lhs.value < rhs.value }
    static func - (lhs: Clock, rhs: Clock) -> Clock { Clock(lhs.value - rhs.value) }
    static func + (lhs: Clock, rhs: Clock) -> Clock { Clock(lhs.value + rhs.value) }

    var timeSlot: TimeSlot {
        let index = (Int(value + 2) / 4) - 1
        return TimeSlot.allCases.indices.contains(index) ? TimeSlot.allCases[index] : .dusk
    }

    /// The traditional Tamil division of the day into six parts.
    enum TimeSlot: String, CaseIterable, Sendable {
        case dawn      // வைகறை Vaikarai 2-6
        case morning   // காலை Kalai 6-10
        case midday    // நண்பகல் Nanpagal 10-14
        case sunset    // எற்பாடு Erppadu 14-18
        case evening   // மாலை Maalai 18-22
        case dusk      // யாமம் Yaamam 22-0, 0-2

        var tamilName: String {
            switch self {
            case .dawn: "வைகறை"
            case .morning: "காலை"
            case .midday: "நண்பகல்"
            case .sunset: "எற்பாடு"
            case .evening: "மாலை"
            case .dusk: "யாமம்"
            }
        }
    }

    static let zero = Clock(0)
}
