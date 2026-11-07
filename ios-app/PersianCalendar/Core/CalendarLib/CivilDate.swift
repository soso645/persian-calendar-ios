import Foundation

/// The Gregorian calendar, falling back to Julian before 15 October 1582.
struct CivilDate: AbstractDate {
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

    func toJdn() -> Int { jdnFromCivil(year, month, dayOfMonth) }

    static func fromJdn(_ jdn: Int) -> DateTriplet { civilFromJdn(jdn) }

    var description: String { "CivilDate(\(year), \(month), \(dayOfMonth))" }
}
