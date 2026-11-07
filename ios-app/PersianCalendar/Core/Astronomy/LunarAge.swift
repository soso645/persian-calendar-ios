import Foundation

/// How far the Moon is through its synodic cycle, as a fraction in [0, 1).
struct LunarAge: Sendable {
    private let fraction: Double

    private init(fraction: Double) { self.fraction = fraction }

    static func fromDegrees(_ degrees: Double) -> LunarAge {
        LunarAge(fraction: floorMod(degrees, 360.0) / 360)
    }

    /// Actually not a constant — it decreases very slowly.
    static let period = 29.530588853

    var isAscending: Bool { fraction < 0.5 }

    var days: Double { fraction * Self.period }

    /// See also https://github.com/janczer/goMoonPhase/blob/0363844/MoonPhase.go#L94
    var absolutePhaseValue: Double { (1 - cos(fraction * 2 * .pi)) / 2 }

    /// Eight is the number of phases in this system, named by most cultures.
    func toPhase() -> Phase {
        Phase(rawValue: Int((fraction * 8).rounded())) ?? .newMoon
    }

    enum Phase: Int, CaseIterable, Sendable {
        case newMoon = 0
        case waxingCrescent
        case firstQuarter
        case waxingGibbous
        case fullMoon
        case waningGibbous
        case thirdQuarter
        case waningCrescent

        private var rawEmoji: String {
            switch self {
            case .newMoon: "🌑"
            case .waxingCrescent: "🌒"
            case .firstQuarter: "🌓"
            case .waxingGibbous: "🌔"
            case .fullMoon: "🌕"
            case .waningGibbous: "🌖"
            case .thirdQuarter: "🌗"
            case .waningCrescent: "🌘"
            }
        }

        /// In the southern hemisphere the lit limb is mirrored, so the emoji is too.
        func emoji(coordinates: Coordinates?) -> String {
            if rawValue == 0 { return rawEmoji }
            if coordinates?.isSouthernHemisphere == true {
                return Phase.allCases[Phase.allCases.count - rawValue].rawEmoji
            }
            return rawEmoji
        }
    }
}
