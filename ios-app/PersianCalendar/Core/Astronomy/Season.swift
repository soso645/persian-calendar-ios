import Foundation

/// The four seasons, as determined by the Sun's ecliptic longitude.
enum Season: Int, CaseIterable, Sendable {
    case spring = 0, summer, autumn, winter

    /// Localization key; the display name comes from the string catalog.
    var nameKey: String {
        switch self {
        case .spring: "spring"
        case .summer: "summer"
        case .autumn: "autumn"
        case .winter: "winter"
        }
    }

    /// Packed ARGB, matching the Android original's colors.
    var argb: UInt32 {
        switch self {
        case .spring: 0xcc80_aa15
        case .summer: 0xccfa_b000
        case .autumn: 0xccbf_8015
        case .winter: 0xcc55_80aa
        }
    }

    static func fromTimeInMillis(_ timeInMillis: Int, coordinates: Coordinates?) -> Season {
        let sunLongitude = sunPosition(AstroTime.fromMillisecondsSince1970(timeInMillis)).elon
        var seasonIndex = Int(floor(sunLongitude / 90))
        // Southern hemisphere consideration
        if coordinates?.isSouthernHemisphere == true { seasonIndex = (seasonIndex + 2) % 4 }
        return Season(rawValue: seasonIndex) ?? .spring
    }
}
