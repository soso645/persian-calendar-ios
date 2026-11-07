import Foundation

/// The Hijri calendar.
///
/// Which tabulation is used depends on ``useUmmAlQura``, and the result is shifted by
/// ``islamicOffset``. Both are global settings in the Kotlin original and are kept global here so
/// that every conversion site behaves identically without threading configuration through the app.
struct IslamicDate: AbstractDate {
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
        let tableResult = Self.useUmmAlQura
            ? UmmAlQuraConverter.toJdn(year, month, dayOfMonth)
            : IranianIslamicDateConverter.toJdn(year, month, dayOfMonth)

        return tableResult != -1
            ? tableResult - Self.islamicOffset
            : FallbackIslamicConverter.toJdn(year, month, dayOfMonth) - Self.islamicOffset
    }

    static func fromJdn(_ jdn: Int) -> DateTriplet {
        let jdn = jdn + islamicOffset
        let tabulated = useUmmAlQura
            ? UmmAlQuraConverter.fromJdn(jdn)
            : IranianIslamicDateConverter.fromJdn(jdn)
        return tabulated ?? FallbackIslamicConverter.fromJdn(jdn)
    }

    var description: String { "IslamicDate(\(year), \(month), \(dayOfMonth))" }

    // MARK: - Global configuration

    // These mirror the Kotlin original's mutable statics, which carry the same thread-safety
    // characteristics. They are written once during settings load, before any conversion runs.
    nonisolated(unsafe) static var useUmmAlQura = false
    nonisolated(unsafe) static var islamicOffset = 0
}
