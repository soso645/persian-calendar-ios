import Foundation

/// A purely computational Islamic calendar, used for dates outside the tabulated ranges of
/// `IranianIslamicDateConverter` and `UmmAlQuraConverter`.
enum FallbackIslamicConverter {
    /// The number of months between Julian day number 1 and the year 1405 A.H., which started
    /// immediately after lunar conjunction number 1048, occurring September 1984 25d 3h 10m UT.
    private static let nMonths = (1405 * 12) + 1

    private static func flr(_ d: Double) -> Int { Int(floor(d)) }

    static func toJdn(_ year: Int, _ month: Int, _ day: Int) -> Int {
        var year = year
        if year < 0 { year += 1 }
        // Number of months since 1/1/1405
        let k = month + year * 12 - nMonths
        return flr(visibility(k + 1048) + Double(day) + 0.5)
    }

    private static func tmoonphase(_ n: Int, _ nph: Int) -> Double {
        let k = Double(n) + Double(nph) / 4.0
        let T = k / 1236.85
        let t2 = T * T
        let t3 = t2 * T
        let jd = 2415020.75933 + 29.53058868 * k - 0.0001178 * t2 - 0.000000155 * t3
            + 0.00033 * sinOfDegree(166.56 + 132.87 * T - 0.009173 * t2)

        // Sun's mean anomaly
        let sa = toRadians(359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3)

        // Moon's mean anomaly
        let ma = toRadians(306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3)

        // Moon's argument of latitude
        let tf = toRadians(2 * (21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3))

        let xtra: Double
        switch nph {
        case 0, 2:
            xtra = (((0.1734 - 0.000393 * T) * sin(sa))
                + (0.0021 * sin(sa * 2))
                - (0.4068 * sin(ma))
                + (0.0161 * sin(2 * ma))
                - (0.0004 * sin(3 * ma))
                + (0.0104 * sin(tf)))
                - (0.0051 * sin(sa + ma))
                - (0.0074 * sin(sa - ma))
                + (0.0004 * sin(tf + sa))
                - (0.0004 * sin(tf - sa))
                - (0.0006 * sin(tf + ma))
                + (0.001 * sin(tf - ma))
                + (0.0005 * sin(sa + 2 * ma))

        case 1, 3:
            xtra = (((0.1721 - 0.0004 * T) * sin(sa))
                + (0.0021 * sin(sa * 2))
                - (0.628 * sin(ma))
                + (0.0089 * sin(2 * ma))
                - (0.0004 * sin(3 * ma))
                + (0.0079 * sin(tf)))
                - (0.0119 * sin(sa + ma))
                - (0.0047 * sin(sa - ma))
                + (0.0003 * sin(tf + sa))
                - (0.0004 * sin(tf - sa))
                - (0.0006 * sin(tf + ma))
                + (0.0021 * sin(tf - ma))
                + (0.0003 * sin(sa + 2 * ma))
                + (0.0004 * sin(sa - 2 * ma))
                - (0.0003 * sin(2 * sa + ma))
                + (nph == 1
                    ? 0.0028 - (0.0004 * cos(sa)) + (0.0003 * cos(ma))
                    : -0.0028 + (0.0004 * cos(sa)) - (0.0003 * cos(ma)))

        default:
            return 0.0
        }
        // Convert from Ephemeris Time (ET) to (approximate) Universal Time (UT)
        return jd + xtra - (0.41 + (1.2053 * T) + (0.4992 * t2)) / 1440
    }

    private static func visibility(_ n: Int) -> Double {
        // Parameters for Makkah: for a new moon to be visible after sunset on the same day it
        // started, it has to have started before (SUNSET-MINAGE)-TIMZ = 3 A.M. local time.
        let TIMZ: Double = 3
        let MINAGE: Double = 13.5
        let SUNSET: Double = 19.5
        // Approximate
        let TIMDIF = SUNSET - MINAGE
        let jd = tmoonphase(n, 0)
        let d = flr(jd)
        var tf = jd - Double(d)
        if tf <= 0.5 {  // New moon starts in the afternoon
            return jd + 1
        } else {  // New moon starts before noon
            tf = (tf - 0.5) * 24 + TIMZ  // Local time
            // Age at sunset < min for visibility
            return tf > TIMDIF ? jd + 1.0 : jd
        }
    }

    static func fromJdn(_ jd: Int) -> DateTriplet {
        let civil = CivilDate(jdn: jd)
        var year = civil.year
        var month = civil.month
        var day = civil.dayOfMonth
        // `day / 365f` is a Float division in the Kotlin original, so the intermediate is
        // rounded to Float precision before widening. Preserved here deliberately.
        var k = flr(0.6 + (Double(year)
            + Double(month % 2 == 0 ? month : month - 1) / 12.0
            + Double(Float(day) / Float(365)) - 1900) * 12.3685)
        var mjd: Double
        repeat {
            mjd = visibility(k)
            k -= 1
        } while mjd > Double(jd) - 0.5
        k += 1
        let hm = k - 1048
        year = 1405 + (hm / 12)
        month = (hm % 12) + 1
        if hm != 0 && month <= 0 {
            month += 12
            year -= 1
        }
        if year <= 0 { year -= 1 }
        day = flr(Double(jd) - mjd + 0.5)
        return DateTriplet(year: year, month: month, dayOfMonth: day)
    }
}
