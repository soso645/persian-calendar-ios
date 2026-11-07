import Foundation

/// A location on earth.
struct Coordinates: Hashable, Sendable {
    /// Observer latitude, [0-90)
    let latitude: Double
    /// Observer longitude, [0-180)
    let longitude: Double
    /// Observer height/elevation/altitude in meters, 0 is global sea level
    let elevation: Double

    init(latitude: Double, longitude: Double, elevation: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }
}

/// Asr juristic methods.
enum AsrMethod: String, CaseIterable, Sendable {
    /// Shafi`i, Maliki, Ja`fari, Hanbali
    case standard
    /// Hanafi
    case hanafi

    /// Asr shadow factor.
    var asrFactor: Double {
        switch self {
        case .standard: 1.0
        case .hanafi: 2.0
        }
    }
}

/// Different midnight calculation methods.
enum MidnightMethod: String, CaseIterable, Sendable {
    /// Mid Sunset to Sunrise, the non-Jafari default
    case midSunsetToSunrise
    /// Mid Sunset to Fajr, the Jafari default
    case midSunsetToFajr
    /// Mid Maghrib to Sunrise
    case midMaghribToSunrise
    /// Mid Maghrib to Fajr
    case midMaghribToFajr

    /// Whether the method is only meaningful in Jafari, where Sunset and Maghrib differ.
    var isJafariOnly: Bool {
        switch self {
        case .midMaghribToSunrise, .midMaghribToFajr: true
        case .midSunsetToSunrise, .midSunsetToFajr: false
        }
    }
}

/// Adjustment methods for higher latitudes, e.g. Scandinavian countries.
enum HighLatitudesMethod: String, CaseIterable, Sendable {
    /// Middle of night, the default
    case nightMiddle
    /// Angle/60th of night
    case angleBased
    /// 1/7th of night
    case oneSeventh
    /// No adjustment
    case none
}

/// Either a number of minutes or an angle in degrees, depending on `isMinutes`.
struct MinuteOrAngleDouble: Hashable, Sendable {
    let value: Double
    let isMinutes: Bool

    static func deg(_ value: Double) -> MinuteOrAngleDouble {
        MinuteOrAngleDouble(value: value, isMinutes: false)
    }

    static func min(_ value: Double) -> MinuteOrAngleDouble {
        MinuteOrAngleDouble(value: value, isMinutes: true)
    }
}

enum CalculationMethod: String, CaseIterable, Sendable {
    /// Muslim World League
    case MWL
    /// Islamic Society of North America (ISNA)
    case ISNA
    /// Egyptian General Authority of Survey
    case Egypt
    /// Umm Al-Qura University, Makkah
    case Makkah
    /// University of Islamic Sciences, Karachi
    case Karachi
    /// Institute of Geophysics, University of Tehran
    case Tehran
    /// Shia Ithna-Ashari, Leva Institute, Qum
    case Jafari
    /// France
    case France
    /// Russia
    case Russia
    /// Singapore
    case Singapore

    var fajr: MinuteOrAngleDouble {
        switch self {
        case .MWL: .deg(18)
        case .ISNA: .deg(15)
        case .Egypt: .deg(19.5)
        case .Makkah: .deg(18.5)
        case .Karachi: .deg(18)
        case .Tehran: .deg(17.7)
        case .Jafari: .deg(16)
        case .France: .deg(12)
        case .Russia: .deg(16)
        case .Singapore: .deg(20)
        }
    }

    var isha: MinuteOrAngleDouble {
        switch self {
        case .MWL: .deg(17)
        case .ISNA: .deg(15)
        case .Egypt: .deg(17.5)
        case .Makkah: .min(90)
        case .Karachi: .deg(18)
        case .Tehran: .deg(14)
        case .Jafari: .deg(14)
        case .France: .deg(12)
        case .Russia: .deg(15)
        case .Singapore: .deg(18)
        }
    }

    var maghrib: MinuteOrAngleDouble {
        switch self {
        case .Tehran: .deg(4.5)
        case .Jafari: .deg(4)
        default: .min(0)
        }
    }

    var defaultMidnight: MidnightMethod {
        switch self {
        case .Tehran, .Jafari: .midSunsetToFajr
        default: .midSunsetToSunrise
        }
    }

    /// Whether the calculation method is a Jafari one.
    var isJafari: Bool { defaultMidnight == .midSunsetToFajr }
}
