import Foundation

/// The Solar Hijri (Shamsi/Jalali) calendar.
///
/// Conversion goes through three tiers, in order: the official lookup table for 1304–1498, the
/// pre-reform Tsybulsky tables, and finally the astronomical algorithm.
struct PersianDate: AbstractDate {
    let year: Int
    let month: Int
    let dayOfMonth: Int

    init(year: Int, month: Int, dayOfMonth: Int) {
        self.year = year
        self.month = month
        self.dayOfMonth = dayOfMonth
    }

    init(jdn: Int) {
        self.init(triplet: Self.fromJdn(jdn))
    }

    func toJdn() -> Int {
        var result = LookupTableConverter.toJdn(year, month, dayOfMonth)
        if result == -1 { result = OldEraConverter.toJdn(year, month, dayOfMonth) }
        if result == -1 { result = jdnFromPersian(year, month, dayOfMonth) }
        return result
    }

    static func fromJdn(_ jdn: Int) -> DateTriplet {
        LookupTableConverter.fromJdn(jdn) ?? OldEraConverter.fromJdn(jdn) ?? persianFromJdn(jdn)
    }

    var description: String { "PersianDate(\(year), \(month), \(dayOfMonth))" }

    /// Always Borji (old era) — never the new era's fixed month lengths.
    static func borjiFromJdn(_ jdn: Int) -> DateTriplet {
        OldEraConverter.fromJdn(jdn) ?? persianFromJdn(jdn, alwaysBorji: true)
    }

    /// The first six months have 31 days, the next five 30, and the last 29 (30 in leap years).
    private static let daysToMonth = [0, 31, 62, 93, 124, 155, 186, 216, 246, 276, 306, 336, 366]

    static func monthFromDaysCount(_ days: Int) -> Int {
        daysToMonth.firstIndex(where: { $0 >= days }) ?? -1
    }

    static func daysInPreviousMonths(_ month: Int) -> Int { daysToMonth[month - 1] }
}
