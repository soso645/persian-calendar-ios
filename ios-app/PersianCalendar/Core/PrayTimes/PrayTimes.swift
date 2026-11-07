import Foundation

/// Canonical API of the prayer times library.
///
/// All times are real numbers in [0-24), each a portion of a day.
struct PrayTimes: Sendable {
    /// Imsak, time fasting starts in Ramadan.
    let imsak: Double
    /// Fajr or dawn (Adhan).
    let fajr: Double
    /// Sunrise.
    let sunrise: Double
    /// Dhuhr or midday (Adhan).
    let dhuhr: Double
    /// Asr or afternoon (Adhan).
    let asr: Double
    /// Sunset.
    let sunset: Double
    /// Maghrib or sunset (Adhan).
    let maghrib: Double
    /// Isha or night (Adhan).
    let isha: Double
    /// Midnight.
    let midnight: Double

    // Default times
    private static let defaultImsak = 5.0 / 24
    private static let defaultFajr = 5.0 / 24
    private static let defaultSunrise = 6.0 / 24
    private static let defaultDhuhr = 12.0 / 24
    private static let defaultAsr = 13.0 / 24
    private static let defaultSunset = 18.0 / 24
    private static let defaultMaghrib = 18.0 / 24
    private static let defaultIsha = 18.0 / 24
    private static let defaultTimeImsak = MinuteOrAngleDouble.min(10)
    private static let defaultTimeDhuhr = MinuteOrAngleDouble.min(0)

    /// - Parameters:
    ///   - method: Variant of pray times calculation method.
    ///   - year: Gregorian calendar year, e.g. 2020.
    ///   - month: Gregorian calendar month of year, 1-12 (NOT zero-indexed).
    ///   - dayOfMonth: Gregorian calendar day of month, 1-31.
    ///   - offset: Time zone offset in hours; for GMT-1:00 it is -1, for GMT+3:30 it is 3.5.
    ///   - coordinates: Coordinate on earth.
    ///   - asrMethod: Asr calculation method.
    ///   - highLatitudesMethod: Correction used for high latitude places.
    ///   - midnightMethod: Pass nil to use the calculation method's default.
    init(
        method: CalculationMethod,
        year: Int,
        month: Int,
        dayOfMonth: Int,
        offset: Double,
        coordinates: Coordinates,
        asrMethod: AsrMethod,
        highLatitudesMethod: HighLatitudesMethod,
        midnightMethod: MidnightMethod? = nil
    ) {
        let jdate = Self.julian(year, month, dayOfMonth) - coordinates.longitude / (15 * 24)

        // Compute prayer times at the given Julian date
        var imsak = Self.sunAngleTime(
            jdate, Self.defaultTimeImsak, Self.defaultImsak, ccw: true, coordinates)
        var fajr = Self.sunAngleTime(jdate, method.fajr, Self.defaultFajr, ccw: true, coordinates)
        let riseAngle = Self.riseSetAngle(coordinates)  // Sun angle for sunset/sunrise
        var sunrise = Self.sunAngleTime(
            jdate, riseAngle, Self.defaultSunrise, ccw: true, coordinates)
        var dhuhr = Self.midDay(jdate, Self.defaultDhuhr)
        var asr = Self.asrTime(jdate, asrMethod.asrFactor, Self.defaultAsr, coordinates)
        var sunset = Self.sunAngleTime(
            jdate, riseAngle, Self.defaultSunset, ccw: false, coordinates)
        var maghrib = Self.sunAngleTime(
            jdate, method.maghrib, Self.defaultMaghrib, ccw: false, coordinates)
        var isha = Self.sunAngleTime(jdate, method.isha, Self.defaultIsha, ccw: false, coordinates)

        // Adjust times
        let addToAll = offset - coordinates.longitude / 15
        imsak += addToAll
        fajr += addToAll
        sunrise += addToAll
        dhuhr += addToAll
        asr += addToAll
        sunset += addToAll
        maghrib += addToAll
        isha += addToAll

        if highLatitudesMethod != .none {
            // Adjust times for locations in higher latitudes
            let nightTime = Self.timeDiff(sunset, sunrise)
            imsak = Self.adjustHLTime(
                highLatitudesMethod, imsak, sunrise, Self.defaultTimeImsak.value, nightTime,
                ccw: true)
            fajr = Self.adjustHLTime(
                highLatitudesMethod, fajr, sunrise, method.fajr.value, nightTime, ccw: true)
            isha = Self.adjustHLTime(
                highLatitudesMethod, isha, sunset, method.isha.value, nightTime, ccw: false)
            maghrib = Self.adjustHLTime(
                highLatitudesMethod, maghrib, sunset, method.maghrib.value, nightTime, ccw: false)
        }

        if Self.defaultTimeImsak.isMinutes { imsak = fajr - Self.defaultTimeImsak.value / 60 }
        if method.maghrib.isMinutes { maghrib = sunset + method.maghrib.value / 60 }
        if method.isha.isMinutes { isha = maghrib + method.isha.value / 60 }
        dhuhr += Self.defaultTimeDhuhr.value / 60

        let midnight: Double
        switch midnightMethod ?? method.defaultMidnight {
        case .midSunsetToSunrise: midnight = sunset + Self.timeDiff(sunset, sunrise) / 2
        case .midSunsetToFajr: midnight = sunset + Self.timeDiff(sunset, fajr) / 2
        case .midMaghribToSunrise: midnight = maghrib + Self.timeDiff(maghrib, sunrise) / 2
        case .midMaghribToFajr: midnight = maghrib + Self.timeDiff(maghrib, fajr) / 2
        }

        self.imsak = Self.fixHour(imsak)
        self.fajr = Self.fixHour(fajr)
        self.sunrise = Self.fixHour(sunrise)
        self.dhuhr = Self.fixHour(dhuhr)
        self.asr = Self.fixHour(asr)
        self.sunset = Self.fixHour(sunset)
        self.maghrib = Self.fixHour(maghrib)
        self.isha = Self.fixHour(isha)
        self.midnight = Self.fixHour(midnight)
    }

    // MARK: - Internals

    private struct DeclEqt {
        let declination: Double
        let equation: Double
    }

    /// Compute mid-day time.
    private static func midDay(_ jdate: Double, _ time: Double) -> Double {
        fixHour(12 - sunPosition(jdate + time).equation)
    }

    /// Compute the time at which the sun reaches a specific angle below the horizon.
    ///
    /// The degree/radian conversions below look mismatched but are load-bearing scaling in the
    /// original algorithm, so they are reproduced exactly.
    private static func sunAngleTime(
        _ jdate: Double, _ angle: MinuteOrAngleDouble, _ time: Double, ccw: Bool,
        _ coordinates: Coordinates
    ) -> Double {
        let decl = sunPosition(jdate + time).declination
        let noon = rad(midDay(jdate, time))
        let t = acos(
            (-sin(rad(angle.value)) - sin(decl) * sin(rad(coordinates.latitude)))
                / (cos(decl) * cos(rad(coordinates.latitude)))
        ) / 15
        return deg(noon + (ccw ? -t : t))
    }

    /// Compute asr time.
    private static func asrTime(
        _ jdate: Double, _ factor: Double, _ time: Double, _ coordinates: Coordinates
    ) -> Double {
        let decl = sunPosition(jdate + time).declination
        let angle = -atan(1 / (factor + tan(abs(rad(coordinates.latitude) - decl))))
        return sunAngleTime(jdate, .deg(deg(angle)), time, ccw: false, coordinates)
    }

    /// Compute the declination angle of the sun and the equation of time.
    ///
    /// Ref: http://aa.usno.navy.mil/faq/docs/SunApprox.php
    private static func sunPosition(_ jd: Double) -> DeclEqt {
        let D = jd - 2451545
        let g = (357.529 + 0.98560028 * D).truncatingRemainder(dividingBy: 360)
        let q = (280.459 + 0.98564736 * D).truncatingRemainder(dividingBy: 360)
        let L = (q + 1.915 * sin(rad(g)) + 0.020 * sin(rad(2 * g)))
            .truncatingRemainder(dividingBy: 360)

        let e = 23.439 - 0.00000036 * D
        let RA = deg(atan2(cos(rad(e)) * sin(rad(L)), cos(rad(L)))) / 15
        let eqt = q / 15 - fixHour(RA)
        let decl = asin(sin(rad(e)) * sin(rad(L)))
        return DeclEqt(declination: decl, equation: eqt)
    }

    /// Convert a Gregorian date to a Julian day.
    ///
    /// Ref: Astronomical Algorithms by Jean Meeus
    private static func julian(_ year: Int, _ month: Int, _ day: Int) -> Double {
        var year = year
        var month = month
        if month <= 2 {
            year -= 1
            month += 12
        }
        let A = floor(Double(year) / 100.0)
        let B = 2 - A + floor(A / 4)
        return floor(365.25 * Double(year + 4716)) + floor(30.6001 * Double(month + 1))
            + Double(day) + B - 1524.5
    }

    /// Sun angle for sunset/sunrise.
    private static func riseSetAngle(_ coordinates: Coordinates) -> MinuteOrAngleDouble {
        // var earthRad = 6371009; // in meters
        // var angle = DMath.arccos(earthRad / (earthRad + elv));
        let angle = 0.0347 * sqrt(Swift.max(coordinates.elevation, 0.0))  // an approximation
        return .deg(0.833 + angle)
    }

    /// Adjust a time for higher latitudes.
    private static func adjustHLTime(
        _ highLatMethod: HighLatitudesMethod, _ time: Double, _ bbase: Double, _ angle: Double,
        _ night: Double, ccw: Bool
    ) -> Double {
        var time = time
        let portion = nightPortion(highLatMethod, angle, night)
        let diff = ccw ? timeDiff(time, bbase) : timeDiff(bbase, time)
        if time.isNaN || diff > portion {
            time = bbase + (ccw ? -portion : portion)
        }
        return time
    }

    /// The night portion used for adjusting times in higher latitudes.
    private static func nightPortion(
        _ method: HighLatitudesMethod, _ angle: Double, _ night: Double
    ) -> Double {
        let factor: Double =
            switch method {
            case .angleBased: 1.0 / 60 * angle
            case .oneSeventh: 1.0 / 7
            default: 0.5
            }
        return factor * night
    }

    /// Compute the difference between two times.
    private static func timeDiff(_ time1: Double, _ time2: Double) -> Double {
        fixHour(time2 - time1)
    }

    private static func fixHour(_ a: Double) -> Double {
        let result = a.truncatingRemainder(dividingBy: 24)
        return result < 0 ? 24 + result : result
    }

    private static func rad(_ x: Double) -> Double { x * .pi / 180 }
    private static func deg(_ x: Double) -> Double { x * 180 / .pi }
}
