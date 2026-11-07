import Foundation

/// The twelve zodiac signs, with both tropical and IAU-constellation boundaries.
///
/// The table is from https://en.wikipedia.org/wiki/Sidereal_and_tropical_astrology
///
/// | Constellation |       Tropical date       |  Based on IAU boundaries  |
/// |---------------|---------------------------|---------------------------|
/// | Aries         | March 21 – April 19       | April 18 – May 13         |
/// | Taurus        | April 20 – May 20         | May 13 – June 21          |
/// | Gemini        | May 21 – June 20          | June 21 – July 20         |
/// | Cancer        | June 21 – July 22         | July 20 – August 10       |
/// | Leo           | July 23 – August 22       | August 10 – September 16  |
/// | Virgo         | August 23 – September 22  | September 16 – October 30 |
/// | Libra         | September 23 – October 22 | October 30 – November 23  |
/// | Scorpio       | October 23 – November 21  | November 23 – November 29 |
/// | Sagittarius   | November 22 – December 21 | December 17 – January 20  |
/// | Capricorn     | December 22 – January 19  | January 20 – February 16  |
/// | Aquarius      | January 21 – February 19  | February 16 – March 11    |
/// | Pisces        | February 19 – March 20    | March 11 – April 18       |
///
/// See also: https://en.wikipedia.org/wiki/Lunar_station#Arabic_manzil
enum Zodiac: Int, CaseIterable, Sendable {
    case aries = 0    // 0-30 (tropical)
    case taurus       // 30-60
    case gemini       // 60-90
    case cancer       // 90-120
    case leo          // 120-150
    case virgo        // 150-180
    case libra        // 180-210
    case scorpio      // 210-240
    case sagittarius  // 240-270
    case capricorn    // 270-300
    case aquarius     // 300-330
    case pisces       // 330-360

    var symbol: String {
        switch self {
        case .aries: "♈"
        case .taurus: "♉"
        case .gemini: "♊"
        case .cancer: "♋"
        case .leo: "♌"
        case .virgo: "♍"
        case .libra: "♎"
        case .scorpio: "♏"
        case .sagittarius: "♐"
        case .capricorn: "♑"
        case .aquarius: "♒"
        case .pisces: "♓"
        }
    }

    /// Localization key; the display name comes from the string catalog.
    var titleKey: String {
        switch self {
        case .aries: "aries"
        case .taurus: "taurus"
        case .gemini: "gemini"
        case .cancer: "cancer"
        case .leo: "leo"
        case .virgo: "virgo"
        case .libra: "libra"
        case .scorpio: "scorpio"
        case .sagittarius: "sagittarius"
        case .capricorn: "capricorn"
        case .aquarius: "aquarius"
        case .pisces: "pisces"
        }
    }

    private var iauRangeStart: Double {
        switch self {
        case .aries: 33.18
        case .taurus: 51.16
        case .gemini: 93.44
        case .cancer: 119.48
        case .leo: 135.30
        case .virgo: 173.34
        case .libra: 224.17
        case .scorpio: 242.57
        case .sagittarius: 271.26
        case .capricorn: 302.49
        case .aquarius: 311.72
        case .pisces: 348.58
        }
    }

    private var iauNextRangeStart: Double {
        Zodiac(rawValue: rawValue + 1)?.iauRangeStart ?? (Zodiac.aries.iauRangeStart + 360)
    }

    var iauRange: [Double] { [iauRangeStart, iauNextRangeStart] }

    var tropicalRange: [Double] { [Double(rawValue) * 30.0, Double(rawValue + 1) * 30.0] }

    static func fromPersianCalendar(_ persianDate: PersianDate) -> Zodiac {
        Zodiac(rawValue: persianDate.month - 1) ?? .aries
    }

    /// Also known as Falaki (فلکی).
    static func fromIau(_ longitude: Double) -> Zodiac {
        if longitude < Zodiac.aries.iauRangeStart { return .pisces }
        return allCases.first { longitude < $0.iauNextRangeStart } ?? .pisces
    }

    /// Also known as Borji (برجی), or Tropical (اعتدالی).
    static func fromTropical(_ longitude: Double) -> Zodiac {
        Zodiac(rawValue: Int(floor(longitude / 30))) ?? .pisces
    }

    /// Covers both the tropical and IAU ranges of Scorpio.
    static let scorpioRange: ClosedRange<Double> =
        Zodiac.scorpio.tropicalRange[0]...Zodiac.scorpio.iauNextRangeStart
}

extension Zodiac {
    /// Localized sign name for the three shipped languages.
    func localizedTitle(_ language: AppLanguage) -> String {
        let names: [AppLanguage: [String]] = [
            .fa: [
                "حَمَل", "ثور", "جوزا", "سرطان", "اسد", "سنبله",
                "میزان", "عقرب", "قوس", "جدی", "دلو", "حوت",
            ],
            .ar: [
                "الحمل", "الثور", "الجوزاء", "السرطان", "الأسد", "العذراء",
                "الميزان", "العقرب", "القوس", "الجدي", "الدلو", "الحوت",
            ],
            .en: [
                "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
                "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
            ],
        ]
        return names[language]?[rawValue] ?? "\(self)"
    }
}
