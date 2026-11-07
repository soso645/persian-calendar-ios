import Foundation

/// Arabic lots (سهام), as used in the classical Islamic tradition for year charts.
///
/// https://en.wikipedia.org/wiki/Arabic_parts
///
/// The Kotlin source carries detailed provenance notes and marks several of these as drafts
/// brute-forced from a single 1225 AP manuscript rather than confirmed by a classical text. Those
/// caveats are reproduced per case below, because the formulas are not all textually attested.
enum Lot: String, CaseIterable, Sendable {
    /// Part of Fortune: day = ASC + ☽ − ☉, night = ASC + ☉ − ☽.
    ///
    /// Moon (material fortune) and Sun (vitality); the two luminaries, the foundational lot.
    /// https://en.wikipedia.org/wiki/Arabic_parts#Calculating_the_Lot_of_Fortune
    case fortune

    /// Part of Kings: day = ASC + ☉ − ♃, night = ASC + ♃ − ☉.
    ///
    /// ⚠️ Draft. Classical "Kings" lots use ☽/♄ or ☽/♂, not ☉/♃. The Sultan name and this
    /// day/night assignment come from the 1225 manuscript only.
    case sultan

    /// Part of Wheat: day = ASC + ☿ − ♄, night = ASC + ♄ − ☿.
    ///
    /// ⚠️ Draft. Abu Ma'shar has this ☿/♄ pair under a different name; another source attests
    /// سهم الحنطة with a different body pair entirely.
    case wheat

    /// Part of Grapes: day = ASC + ♃ − ♀, night = ASC + ♀ − ♃.
    ///
    /// ⚠️ Draft. The ♃/♀ day formula appears in Abu Ma'shar as "Love"; no source confirms the
    /// grape name.
    case grapes

    var arabicTitle: String {
        switch self {
        case .fortune: "سهم السعادة"
        case .sultan: "سهم السلطان"
        case .wheat: "سهم الحنطة"
        case .grapes: "سهم العنب"
        }
    }

    /// The body pair, in diurnal order.
    private var bodies: (first: Body, second: Body) {
        switch self {
        case .fortune: (.moon, .sun)
        case .sultan: (.sun, .jupiter)
        case .wheat: (.mercury, .saturn)
        case .grapes: (.jupiter, .venus)
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch language {
        case .fa, .ar: arabicTitle
        case .en: "\(self)".capitalized
        }
    }

    /// `(ASC + x − y) mod 360`, with the body pair reversed for a nocturnal chart.
    func calculate(ascendant: Double, isDiurnal: Bool, time: AstroTime) -> Double {
        let pair = bodies
        let x = geocentricLongitudeAndDistance(
            of: isDiurnal ? pair.first : pair.second, time: time
        ).longitude
        let y = geocentricLongitudeAndDistance(
            of: isDiurnal ? pair.second : pair.first, time: time
        ).longitude
        return floorMod(ascendant + x - y, 360.0)
    }
}
