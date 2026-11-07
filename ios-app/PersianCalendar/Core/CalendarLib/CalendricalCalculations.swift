// Ported from the Kotlin `io.github.persiancalendar.calendar.util.CalendricalCalculations`, which
// was itself ported from
// https://github.com/roozbehp/persiancalendar/blob/daf8fb2b46466a324cee98833c19c36aa5d97f39/persiancalendar.py
// released under the Apache 2.0 license.
//
// See also https://github.com/unicode-org/icu4x/tree/6187c85/utils/calendrical_calculations

import Foundation

// MARK: - Small helpers

/// The value of x shifted into the range [a..b). Returns x if a=b.
private func mod3(_ x: Double, _ a: Int, _ b: Int) -> Double {
    a == b ? x : Double(a) + (x - Double(a)).truncatingRemainder(dividingBy: Double(b - a))
}

/// Sum powers of x with coefficients (from order 0 up) in list a.
private func poly(_ indeterminate: Double, _ coefficients: [Double]) -> Double {
    var sum = coefficients[0]
    var indeterminateRaised = 1.0
    for i in 1..<coefficients.count {
        indeterminateRaised *= indeterminate
        sum += coefficients[i] * indeterminateRaised
    }
    return sum
}

/// Identity function for fixed dates/moments. If internal timekeeping is shifted, change epoch to
/// be the RD date of origin of the internal count. epoch should be an integer.
private func rd(_ tee: Int) -> Int {
    let epoch = 0
    return tee - epoch
}

// MARK: - Gregorian

/// Fixed date of start of the (proleptic) Gregorian calendar.
private let GREGORIAN_EPOCH = rd(1)

/// True if gYear is a leap year on the Gregorian calendar.
private func gregorianLeapYear(_ gYear: Int) -> Bool {
    guard gYear % 4 == 0 else { return false }
    switch gYear % 400 {
    case 100, 200, 300: return false
    default: return true
    }
}

/// Fixed date equivalent to the Gregorian date.
func fixedFromGregorian(_ year: Int, _ month: Int, _ day: Int) -> Int {
    GREGORIAN_EPOCH - 1              // Days before start of calendar
        + 365 * (year - 1)           // Ordinary days since epoch
        + floorDiv(year - 1, 4)      // Julian leap days since epoch...
        - floorDiv(year - 1, 100)    // ...minus century years since epoch...
        + floorDiv(year - 1, 400)    // plus years since epoch divisible by 400.
        // Days in prior months this year assuming 30-day Feb
        + (367 * month - 362) / 12
        // Correct for 28- or 29-day Feb
        + (month <= 2 ? 0 : (gregorianLeapYear(year) ? -1 : -2))
        + day                        // Days so far this month.
}

/// Gregorian year corresponding to the fixed date.
private func gregorianYearFromFixed(_ date: Int) -> Int {
    let d0 = date - GREGORIAN_EPOCH  // Prior days.
    let n400 = d0 / 146097           // Completed 400-year cycles.
    let d1 = d0 % 146097             // Prior days not in n400.
    let n100 = d1 / 36524            // 100-year cycles not in n400.
    let d2 = d1 % 36524              // Prior days not in n400 or n100.
    let n4 = d2 / 1461               // 4-year cycles not in n400 or n100.
    let d3 = d2 % 1461               // Prior days not in n400, n100, or n4.
    let n1 = d3 / 365                // Years not in n400, n100, or n4.
    let year = 400 * n400 + 100 * n100 + 4 * n4 + n1
    if n100 == 4 || n1 == 4 {
        return year                  // Date is day 366 in a leap year.
    } else {
        return year + 1              // Date is ordinal day (d % 365 + 1) in (year + 1).
    }
}

/// Fixed date of January 1 in gYear.
private func gregorianNewYear(_ gYear: Int) -> Int { fixedFromGregorian(gYear, 1, 1) }

/// Gregorian (year, month, day) corresponding to fixed date.
func gregorianFromFixed(_ date: Int) -> DateTriplet {
    let year = gregorianYearFromFixed(date)
    let priorDays = date - gregorianNewYear(year)  // This year
    // To simulate a 30-day Feb
    let correction: Int
    if date < fixedFromGregorian(year, 3, 1) {
        correction = 0
    } else if gregorianLeapYear(year) {
        correction = 1
    } else {
        correction = 2
    }
    let month = (12 * (priorDays + correction) + 373) / 367  // Assuming a 30-day Feb
    // Calculate the day by subtraction.
    let day = date - fixedFromGregorian(year, month, 1) + 1
    return DateTriplet(year: year, month: month, dayOfMonth: day)
}

/// Number of days from Gregorian date 1 until date 2.
private func gregorianDateDifference(
    _ year1: Int, _ month1: Int, _ day1: Int,
    _ year2: Int, _ month2: Int, _ day2: Int
) -> Int {
    fixedFromGregorian(year2, month2, day2) - fixedFromGregorian(year1, month1, day1)
}

// MARK: - Julian

/// Fixed date of start of the Julian calendar.
private let JULIAN_EPOCH = fixedFromGregorian(0, 12, 30)

/// True if jYear is a leap year on the Julian calendar.
private func julianLeapYear(_ jYear: Int) -> Bool { (jYear % 4) == (jYear > 0 ? 0 : 3) }

/// Fixed date equivalent to the Julian date.
func fixedFromJulian(_ year: Int, _ month: Int, _ day: Int) -> Int {
    let y = year < 0 ? year + 1 : year  // No year zero
    return JULIAN_EPOCH - 1             // Days before start of calendar
        + 365 * (y - 1)                 // Ordinary days since epoch.
        + floorDiv(y - 1, 4)            // Leap days since epoch...
        // Days in prior months this year, assuming 30-day Feb
        + ((367 * month - 362) / 12)
        // Correct for 28- or 29-day Feb
        + (month <= 2 ? 0 : (julianLeapYear(year) ? -1 : -2))
        + day                           // Days so far this month.
}

/// Julian (year, month, day) corresponding to fixed date.
func julianFromFixed(_ date: Int) -> DateTriplet {
    // Nominal year.
    let approx = Int(floor((4.0 * Double(date - JULIAN_EPOCH) + 1464) / 1461.0))
    let year = approx <= 0 ? approx - 1 : approx  // No year 0.

    // This year
    let priorDays = date - fixedFromJulian(year, 1, 1)

    // To simulate a 30-day Feb
    let correction: Int
    if date < fixedFromJulian(year, 3, 1) {
        correction = 0
    } else {
        correction = julianLeapYear(year) ? 1 : 2
    }

    // Assuming a 30-day Feb
    let month = Int(floor((12.0 * Double(priorDays + correction) + 373) / 367.0))

    // Calculate the day by subtraction.
    let day = 1 + (date - fixedFromJulian(year, month, 1))

    return DateTriplet(year: year, month: month, dayOfMonth: day)
}

// MARK: - Astronomical support

/// x hours, as a fraction of a day.
private func hr(_ x: Int) -> Double { Double(x) / 24.0 }

/// d degrees, m arcminutes, s arcseconds.
private func angle(_ d: Int, _ m: Int, _ s: Double) -> Double {
    Double(d) + (Double(m) + s / 60) / 60.0
}

/// Convert angle theta from degrees to radians.
private func radiansFromDegrees(_ theta: Double) -> Double {
    theta.truncatingRemainder(dividingBy: 360) * .pi / 180
}

private func sinDegrees(_ theta: Double) -> Double { sin(radiansFromDegrees(theta)) }
private func cosDegrees(_ theta: Double) -> Double { cos(radiansFromDegrees(theta)) }
private func tanDegrees(_ theta: Double) -> Double { tan(radiansFromDegrees(theta)) }

/// Difference between UT and local mean time at longitude phi as a fraction of a day.
private func zoneFromLongitude(_ phi: Double) -> Double { phi / 360 }

/// Universal time from local teeEll at location.
private func universalFromLocal(_ teeEll: Double, _ longitude: Double) -> Double {
    teeEll - zoneFromLongitude(longitude)
}

/// Local time from sundial time tee at location.
private func localFromApparent(_ tee: Double, _ longitude: Double) -> Double {
    tee - equationOfTime(universalFromLocal(tee, longitude))
}

/// Universal time from sundial time tee at location.
private func universalFromApparent(_ tee: Double, _ longitude: Double) -> Double {
    universalFromLocal(localFromApparent(tee, longitude), longitude)
}

/// Universal time on fixed date of midday at location.
private func midday(_ date: Int, _ longitude: Double) -> Double {
    universalFromApparent(Double(date) + hr(12), longitude)
}

/// Julian centuries since 2000 at moment tee.
private func julianCenturies(_ tee: Double) -> Double {
    (dynamicalFromUniversal(tee) - J2000) / 36525
}

private let obliquityCooefficients: [Double] = [
    0.0,
    angle(0, 0, -46.8150),
    angle(0, 0, -0.00059),
    angle(0, 0, 0.001813),
]

/// Obliquity of ecliptic at moment tee.
private func obliquity(_ tee: Double) -> Double {
    let c = julianCenturies(tee)
    return angle(23, 26, 21.448) + poly(c, obliquityCooefficients)
}

/// Dynamical time at Universal moment teeRomU.
private func dynamicalFromUniversal(_ teeRomU: Double) -> Double {
    teeRomU + ephemerisCorrection(teeRomU)
}

/// Noon at start of Gregorian year 2000.
private let J2000 = hr(12) + Double(gregorianNewYear(2000))

private let MEAN_TROPICAL_YEAR = 365.242189

private let c2006Coefficients: [Double] = [62.92, 0.32217, 0.005589]
private let c1987Coefficients: [Double] = [
    63.86, 0.3345, -0.060374, 0.0017275, 0.000651814, 0.00002373599,
]
private let c1900Coefficients: [Double] = [
    -0.00002, 0.000297, 0.025184, -0.181133, 0.553040, -0.861938, 0.677066, -0.212591,
]
private let c1800Coefficients: [Double] = [
    -0.000009, 0.003844, 0.083563, 0.865736,
    4.867575, 15.845535, 31.332267, 38.291999, 28.316289, 11.636204, 2.043794,
]
private let c1700Coefficients: [Double] = [8.118780842, -0.005092142, 0.003336121, -0.0000266484]
private let c1600Coefficients: [Double] = [120.0, -0.9808, -0.01532, 0.000140272128]
private let c500Coefficients: [Double] = [
    1574.2, -556.01, 71.23472, 0.319781, -0.8503463, -0.005050998, 0.0083572073,
]
private let c0Coefficients: [Double] = [
    10583.6, -1014.41, 33.78311, -5.952053, -0.1798452, 0.022174192, 0.0090316521,
]
private let otherCoefficients: [Double] = [-20.0, 0.0, 32.0]

/// Dynamical Time minus Universal Time (in days) for moment tee.
///
/// Adapted from "Astronomical Algorithms" by Jean Meeus, Willmann-Bell (1991) for years 1600-1986
/// and from polynomials on the NASA Eclipse web site for other years.
private func ephemerisCorrection(_ tee: Double) -> Double {
    let year = gregorianYearFromFixed(Int(floor(tee)))
    switch year {
    case 2051...2150:
        return (-20 + 32 * pow(Double(year - 1820) / 100.0, 2) + 0.5628 * Double(2150 - year)) / 86400

    case 2006...2050:
        return poly(Double(year - 2000), c2006Coefficients) / 86400

    case 1987...2005:
        return poly(Double(year - 2000), c1987Coefficients) / 86400

    case 1900...1986:
        let c = Double(gregorianDateDifference(1900, 1, 1, year, 7, 1)) / 36525.0
        return poly(c, c1900Coefficients)

    case 1800...1899:
        let c = Double(gregorianDateDifference(1900, 1, 1, year, 7, 1)) / 36525.0
        return poly(c, c1800Coefficients)

    case 1700...1799:
        return poly(Double(year - 1700), c1700Coefficients) / 86400

    case 1600...1699:
        return poly(Double(year - 1600), c1600Coefficients) / 86400

    case 500...1599:
        return poly(Double(year - 1000) / 100.0, c500Coefficients) / 86400

    default:
        if -500 < year && year < 500 {
            return poly(Double(year) / 100.0, c0Coefficients) / 86400
        }
        return poly(Double(year - 1820) / 100.0, otherCoefficients) / 86400
    }
}

private let lamdaCoefficient: [Double] = [280.46645, 36000.76983, 0.0003032]
private let anamolyCoefficients: [Double] = [357.52910, 35999.05030, -0.0001559, -0.00000048]
private let eccentricityCoefficients: [Double] = [0.016708617, -0.000042037, -0.0000001236]

/// Equation of time (as fraction of day) for moment tee.
///
/// Adapted from "Astronomical Algorithms" by Jean Meeus, Willmann-Bell, 2nd edn., 1998, p. 185.
private func equationOfTime(_ tee: Double) -> Double {
    let c = julianCenturies(tee)
    let lamda = poly(c, lamdaCoefficient)
    let anomaly = poly(c, anamolyCoefficients)
    let eccentricity = poly(c, eccentricityCoefficients)
    let varepsilon = obliquity(tee)
    let y = pow(tanDegrees(varepsilon / 2), 2)
    let equation = (1.0 / 2 / .pi)
        * (y * sinDegrees(2 * lamda)
            - 2 * eccentricity * sinDegrees(anomaly)
            + 4 * eccentricity * y * sinDegrees(anomaly) * cosDegrees(2 * lamda)
            - 0.5 * y * y * sinDegrees(4 * lamda)
            - 1.25 * eccentricity * eccentricity * sinDegrees(2 * anomaly))
    return signOf(equation) * min(abs(equation), hr(12))
}

private let solarLongitudeCoefficients: [Int] = [
    403406, 195207, 119433, 112392, 3891, 2819, 1721,
    660, 350, 334, 314, 268, 242, 234, 158, 132, 129, 114,
    99, 93, 86, 78, 72, 68, 64, 46, 38, 37, 32, 29, 28, 27, 27,
    25, 24, 21, 21, 20, 18, 17, 14, 13, 13, 13, 12, 10, 10, 10,
    10,
]
private let solarLongitudeMultipliers: [Double] = [
    0.9287892, 35999.1376958, 35999.4089666,
    35998.7287385, 71998.20261, 71998.4403,
    36000.35726, 71997.4812, 32964.4678,
    -19.4410, 445267.1117, 45036.8840, 3.1008,
    22518.4434, -19.9739, 65928.9345,
    9038.0293, 3034.7684, 33718.148, 3034.448,
    -2280.773, 29929.992, 31556.493, 149.588,
    9037.750, 107997.405, -4444.176, 151.771,
    67555.316, 31556.080, -4561.540,
    107996.706, 1221.655, 62894.167,
    31437.369, 14578.298, -31931.757,
    34777.243, 1221.999, 62894.511,
    -4442.039, 107997.909, 119.066, 16859.071,
    -4.578, 26895.292, -39.127, 12297.536,
    90073.778,
]
private let solarLongitudeAddends: [Double] = [
    270.54861, 340.19128, 63.91854, 331.26220,
    317.843, 86.631, 240.052, 310.26, 247.23,
    260.87, 297.82, 343.14, 166.79, 81.53,
    3.50, 132.75, 182.95, 162.03, 29.8,
    266.4, 249.2, 157.6, 257.8, 185.1, 69.9,
    8.0, 197.1, 250.4, 65.3, 162.7, 341.5,
    291.6, 98.5, 146.7, 110.0, 5.2, 342.6,
    230.9, 256.1, 45.3, 242.9, 115.2, 151.8,
    285.3, 53.3, 126.6, 205.7, 85.9,
    146.1,
]

/// Longitude of sun at moment tee.
///
/// Adapted from "Planetary Programs and Tables from -4000 to +2800" by Pierre Bretagnon and
/// Jean-Louis Simon, Willmann-Bell, 1986.
private func solarLongitude(_ tee: Double) -> Double {
    let c = julianCenturies(tee)  // moment in Julian centuries
    var sum = 0.0
    for i in solarLongitudeCoefficients.indices {
        sum += Double(solarLongitudeCoefficients[i])
            * sinDegrees(solarLongitudeAddends[i] + solarLongitudeMultipliers[i] * c)
    }
    let lamda = 282.7771834 + 36000.76953744 * c + 0.000005729577951308232 * sum
    return floorMod(lamda + aberration(tee) + nutation(tee), 360.0)
}

private let nutationCoefficientA: [Double] = [124.90, -1934.134, 0.002063]
private let nutationCoefficientB: [Double] = [201.11, 72001.5377, 0.00057]

/// Longitudinal nutation at moment tee.
private func nutation(_ tee: Double) -> Double {
    let c = julianCenturies(tee)  // moment in Julian centuries
    let capA = poly(c, nutationCoefficientA)
    let capB = poly(c, nutationCoefficientB)
    return -0.004778 * sinDegrees(capA) - 0.0003667 * sinDegrees(capB)
}

/// Aberration at moment tee.
private func aberration(_ tee: Double) -> Double {
    let c = julianCenturies(tee)  // moment in Julian centuries
    return 0.0000974 * cosDegrees(177.63 + 35999.01848 * c) - 0.005575
}

/// Longitude of sun at vernal equinox.
private let SPRING = 0.0

/// Approximate moment at or before tee when solar longitude just exceeded lamda degrees.
private func estimatePriorSolarLongitude(_ lamda: Double, _ tee: Double) -> Double {
    let rate = MEAN_TROPICAL_YEAR / 360  // Mean change of one degree.
    // First approximation.
    let tau = tee - rate * floorMod(solarLongitude(tee) - lamda, 360.0)
    let capDelta = mod3(solarLongitude(tau) - lamda, -180, 180)
    return min(tee, tau - rate * capDelta)
}

// MARK: - Persian

/// Fixed date of start of the Persian calendar.
private let PERSIAN_EPOCH = fixedFromJulian(622, 3, 19)

/// Location of Tehran, Iran — specifically "Dar ul-Funun", https://w.wiki/DjPM
private let TEHRAN: [Double] = [35.683789, 51.421864, 1100.0, +3.5]

/// Middle of Iran.
private let IRAN: [Double] = [35.5, 52.5, 0.0, +3.5]

/// Fixed date of Astronomical Persian New Year on or before fixed date.
func persianNewYearOnOrBefore(_ date: Int, _ longitude: Double) -> Int {
    // Approximate time of equinox.
    let approx = estimatePriorSolarLongitude(SPRING, midday(date, longitude))
    var day = Int(floor(approx)) - 1
    while solarLongitude(midday(day, longitude)) > SPRING + 2 { day += 1 }
    return day
}

/// Fixed date of Borji Persian new month on or before fixed date.
func persianBorjiNewMonthOnOrBefore(_ date: Int, _ month: Int, _ longitude: Double) -> Int {
    // Approximate time of equinox.
    let targetLong = Double(month - 1) * 30.0
    let approx = estimatePriorSolarLongitude(targetLong, midday(date, longitude))
    var day = Int(floor(approx)) - 1
    while true {
        let solarLong = solarLongitude(midday(day, longitude))
        if targetLong + 2 > solarLong && solarLong >= targetLong { break }
        day += 1
    }
    return day
}

/// Fixed date of Astronomical Persian date.
func fixedFromPersian(_ year: Int, _ month: Int, _ day: Int, _ longitude: Double) -> Int {
    let newYear = persianNewYearOnOrBefore(
        PERSIAN_EPOCH + 180  // Fall after epoch.
            + Int(floor(MEAN_TROPICAL_YEAR * Double(0 < year ? year - 1 : year))),
        longitude
    )  // No year zero.
    return newYear - 1  // Days in prior years.
        // Days in prior months this year.
        + (month <= 7 ? 31 * (month - 1) : 30 * (month - 1) + 6)
        + day  // Days so far this month.
}

/// Fixed date of Borji Persian date.
func fixedFromPersianBorji(_ year: Int, _ month: Int, _ day: Int, _ longitude: Double) -> Int {
    let newMonth = persianBorjiNewMonthOnOrBefore(
        PERSIAN_EPOCH + 180
            + Int(floor(MEAN_TROPICAL_YEAR
                * (Double(0 < year ? year - 1 : year) + Double(month - 1) / 12.0))),
        month,
        longitude
    )
    return newMonth - 1  // Days in prior months.
        + day            // Days so far this month.
}

/// Astronomical Persian date corresponding to fixed date.
func persianFromFixed(_ date: Int, _ longitude: Double) -> DateTriplet {
    let newYear = persianNewYearOnOrBefore(date, longitude)
    let y = Int(rint(Double(newYear - PERSIAN_EPOCH) / MEAN_TROPICAL_YEAR)) + 1
    let year = 0 < y ? y : y - 1  // No year zero
    let dayOfYear = date - fixedFromPersian(year, 1, 1, longitude) + 1
    let month = dayOfYear <= 186
        ? Int(ceil(Double(dayOfYear) / 31.0))
        : Int(ceil(Double(dayOfYear - 6) / 30.0))
    // Calculate the day by subtraction
    let day = date - fixedFromPersian(year, month, 1, longitude) + 1
    return DateTriplet(year: year, month: month, dayOfMonth: day)
}

/// Borji Persian date corresponding to fixed date.
func persianBorjiFromFixed(_ date: Int, _ longitude: Double) -> DateTriplet {
    let newYear = persianNewYearOnOrBefore(date, longitude)
    let y = Int(rint(Double(newYear - PERSIAN_EPOCH) / MEAN_TROPICAL_YEAR)) + 1
    let year = 0 < y ? y : y - 1  // No year zero
    var month = 1
    while month < 12 && date >= fixedFromPersianBorji(year, month + 1, 1, longitude) {
        month += 1
    }
    // Calculate the day by subtraction
    let day = date - fixedFromPersianBorji(year, month, 1, longitude) + 1
    return DateTriplet(year: year, month: month, dayOfMonth: day)
}

/// True if year is a leap year on the Persian calendar.
func persianLeapYear(_ year: Int, _ longitude: Double) -> Bool {
    let thisNowruz = fixedFromPersian(year, 1, 1, longitude)
    let nextNowruz = fixedFromPersian(year + 1, 1, 1, longitude)
    return nextNowruz - thisNowruz == 366
}

// MARK: - JDN entry points

private let OFFSET_JDN = 1_721_425
private let START_OF_MODERN_ERA_JDN = 2_424_231  // PersianDate(1304, 1, 1).toJdn()
private let START_OF_MODERN_ERA_YEAR = 1304

func persianFromJdn(_ jdn: Int, alwaysBorji: Bool = false) -> DateTriplet {
    let isModernEra = jdn >= START_OF_MODERN_ERA_JDN
    let fixed = jdn - OFFSET_JDN
    let longitude = (isModernEra ? IRAN : TEHRAN)[1]
    return isModernEra && !alwaysBorji
        ? persianFromFixed(fixed, longitude)
        : persianBorjiFromFixed(fixed, longitude)
}

func jdnFromPersian(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Int {
    let isModernEra = year >= START_OF_MODERN_ERA_YEAR
    let longitude = (isModernEra ? IRAN : TEHRAN)[1]
    let fixed = isModernEra
        ? fixedFromPersian(year, month, dayOfMonth, longitude)
        : fixedFromPersianBorji(year, month, dayOfMonth, longitude)
    return fixed + OFFSET_JDN
}

/// Exposed so the app can display the Julian date. Unstable — may be exposed differently later.
func julianFromJdn(_ jdn: Int) -> DateTriplet { julianFromFixed(jdn - OFFSET_JDN) }

func jdnFromCivil(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Int {
    let isGregorian = (year > 1582)
        || ((year == 1582) && (month > 10))
        || ((year == 1582) && (month == 10) && (dayOfMonth > 14))
    return OFFSET_JDN + (isGregorian
        ? fixedFromGregorian(year, month, dayOfMonth)
        : fixedFromJulian(year, month, dayOfMonth))
}

func civilFromJdn(_ jdn: Int) -> DateTriplet {
    jdn > 2_299_160 ? gregorianFromFixed(jdn - OFFSET_JDN) : julianFromJdn(jdn)
}
