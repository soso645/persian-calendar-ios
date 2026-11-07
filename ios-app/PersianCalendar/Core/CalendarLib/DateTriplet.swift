import Foundation

/// A plain (year, month, dayOfMonth) triple used as the result of JDN conversions.
///
/// The Kotlin original packs these into a single `Int` (16/8/8 bits), which makes values outside
/// `[-32768, 32767]` for the year undefined. Swift uses plain `Int` fields — a strict superset of
/// the defined behaviour, with no packing to get wrong.
struct DateTriplet: Hashable, Sendable {
    let year: Int
    let month: Int
    let dayOfMonth: Int

    init(year: Int, month: Int, dayOfMonth: Int) {
        self.year = year
        self.month = month
        self.dayOfMonth = dayOfMonth
    }
}
