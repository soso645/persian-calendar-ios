/*
 * Ported from
 * https://github.com/echeran/calendar-code2/blob/1de3bfd/clj/clj-calcalc/src/clj_calcalc/core.clj#L5474
 * The original code is under the Apache 2.0 license and is credited in the app's about screen.
 */
import Foundation

/// The Hindu lunar day (tithi), used by the Nepali calendar display.
enum Tithi {
    /// Euclidean division: quotient rounded towards negative infinity.
    private static func quotient(_ m: Int, _ n: Int) -> Int {
        let a = m / n
        let b = m % n
        return (m >= 0 || b == 0) ? a : a - 1
    }

    /// Mean length of the Hindu sidereal year.
    private static let hinduSiderealYear = 365.0 + 279457.0 / 1080000.0

    /// Fixed date of the start of the Hindu calendar (Kali Yuga):
    /// `fixed-from-julian(bce 3102, february 18)`.
    private static let hinduEpoch = -1_132_959

    /// Fixed date of Hindu creation.
    private static let hinduCreation = Double(hinduEpoch) - 1_955_880_000 * hinduSiderealYear

    /// Position in degrees at moment `tee` in a uniform circular orbit of `period` days.
    private static func hinduMeanPosition(_ tee: Double, _ period: Double) -> Double {
        360.0 * (((tee - hinduCreation) / period).truncatingRemainder(dividingBy: 1))
    }

    private static func radiansFromDegrees(_ theta: Double) -> Double {
        theta.truncatingRemainder(dividingBy: 360) * .pi / 180.0
    }

    private static func sinDegrees(_ theta: Double) -> Double { sin(radiansFromDegrees(theta)) }

    /// d degrees, m arcminutes, s arcseconds.
    private static func angle(_ d: Int, _ m: Int, _ s: Double) -> Double {
        Double(d) + (Double(m) + s / 60) / 60.0
    }

    /// Simulates the Hindu sine table; `entry` is an angle as a multiplier of 225'.
    private static func hinduSineTable(_ entry: Int) -> Double {
        let exact = 3438.0 * sinDegrees(Double(entry) * angle(0, 225, 0.0))
        let error = 0.215 * signOf(exact) * signOf(abs(exact) - 1716)
        return rint(exact + error) / 3438.0
    }

    /// Linear interpolation for `theta` in the Hindu table.
    private static func hinduSine(_ theta: Double) -> Double {
        let entry = theta / angle(0, 225, 0.0)
        let fraction = entry.truncatingRemainder(dividingBy: 1)
        return fraction * hinduSineTable(Int(ceil(entry)))
            + (1 - fraction) * hinduSineTable(Int(floor(entry)))
    }

    /// First integer at or above `initial` for which `condition` holds.
    private static func next(_ initial: Int, _ condition: (Int) -> Bool) -> Int {
        var index = initial
        while !condition(index) { index += 1 }
        return index
    }

    /// Inverse of the Hindu sine function.
    private static func hinduArcsin(_ amp: Double) -> Double {
        if amp < 0 { return -hinduArcsin(-amp) }
        let pos = next(0) { amp <= hinduSineTable($0) }
        let below = hinduSineTable(pos - 1)  // Lower value in table
        return angle(0, 225, 0.0)
            * (Double(pos - 1) + (amp - below) / (hinduSineTable(pos) - below))
    }

    /// Longitudinal position at moment `tee`.
    ///
    /// - Parameters:
    ///   - period: period of mean motion, in days.
    ///   - size: ratio of the radii of epicycle and deferent.
    ///   - anomalistic: period of retrograde revolution about the epicycle.
    ///   - change: maximum decrease in epicycle size.
    private static func hinduTruePosition(
        _ tee: Double, _ period: Double, _ size: Double,
        _ anomalistic: Double, _ change: Double
    ) -> Double {
        let lambda = hinduMeanPosition(tee, period)  // Position of epicycle center
        let offset = hinduSine(hinduMeanPosition(tee, anomalistic))  // Sine of anomaly
        let contraction = abs(offset) * change * size
        let equation = hinduArcsin(offset * (size - contraction))  // Equation of center
        return (lambda - equation).truncatingRemainder(dividingBy: 360.0)
    }

    /// Mean length of the Hindu sidereal month.
    private static let hinduSiderealMonth = 27.0 + 4_644_439.0 / 14_438_334.0

    /// Time from apogee to apogee, with bija correction.
    private static let hinduAnomalisticMonth = 1_577_917_828.0 / (57_753_336.0 - 488_199.0)

    private static func hinduLunarLongitude(_ tee: Double) -> Double {
        hinduTruePosition(
            tee, hinduSiderealMonth, 32.0 / 360.0, hinduAnomalisticMonth, 1.0 / 96.0)
    }

    /// Time from aphelion to aphelion.
    private static let hinduAnomalisticYear = 1_577_917_828_000.0 / (4_320_000_000.0 - 387.0)

    private static func hinduSolarLongitude(_ tee: Double) -> Double {
        hinduTruePosition(tee, hinduSiderealYear, 14.0 / 360.0, hinduAnomalisticYear, 1.0 / 42.0)
    }

    /// Longitudinal distance between the sun and moon at moment `tee`.
    private static func hinduLunarPhase(_ tee: Double) -> Double {
        floorMod(hinduLunarLongitude(tee) - hinduSolarLongitude(tee), 360.0)
    }

    /// Phase of the moon (tithi) at moment `tee`, as an integer in 1...30.
    static func hinduLunarDayFromMoment(_ tee: Double) -> Int {
        1 + quotient(Int(hinduLunarPhase(tee)), 12)
    }

    private static let tithiNamesInNepali = [
        "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी (चौथी)", "पञ्चमी", "षष्ठी", "सप्तमी", "अष्टमी",
        "नवमी", "दशमी", "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "पूर्णिमा",

        "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी (चौथी)", "पञ्चमी", "षष्ठी", "सप्तमी", "अष्टमी",
        "नवमी", "दशमी", "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "अमावश्या (औंसी)",
    ]

    /// The tithi's Nepali name for a Unix timestamp in milliseconds.
    static func tithiName(timeMillis: Int) -> String {
        // Note that fixed-from-gregorian([2025, 4, 27]) => 739368
        let tee = 719_162 + Double(timeMillis) / 86_400_000
        let index = hinduLunarDayFromMoment(tee) - 1
        guard tithiNamesInNepali.indices.contains(index) else { return "" }
        return tithiNamesInNepali[index]
    }
}
