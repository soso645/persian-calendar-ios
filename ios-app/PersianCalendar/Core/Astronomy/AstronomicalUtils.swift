import Foundation

/// Where the Moon sits relative to Scorpio on a given day.
///
/// Traditional Persian calendars mark the Moon's passage through Scorpio (قمر در عقرب), and
/// distinguish the tropical (برجی) from the constellation (فلکی) boundary.
enum MoonInScorpioState: Equatable, Sendable {
    /// In Scorpio by the tropical boundary.
    case borji
    /// In Scorpio by the IAU-constellation boundary only.
    case falaki
    /// Enters Scorpio during this day, at the given time.
    case start(Clock)
    /// Leaves Scorpio during this day, at the given time.
    case end(Clock)
}

func isMoonInScorpio(time: AstroTime) -> Bool {
    Zodiac.scorpioRange.contains(eclipticGeoMoon(time).lon)
}

func lunarLongitude(jdn: Jdn, setIranTime: Bool = false, hourOfDay: Int) -> Double {
    eclipticGeoMoon(jdn.toAstronomyTime(hourOfDay: hourOfDay, setIranTime: setIranTime)).lon
}

/// Checks midday only — cheap enough for the calendar table, which needs it for every cell.
func isMoonInScorpio(jdn: Jdn, hourOfDay: Int = 12, setIranTime: Bool = false) -> Bool {
    Zodiac.scorpioRange.contains(
        lunarLongitude(jdn: jdn, setIranTime: setIranTime, hourOfDay: hourOfDay))
}

/// Shift a degree value into `(max - 360, max]`.
private func withMaxDegreeValue(_ degrees: Double, _ max: Double) -> Double {
    var deg = degrees
    while deg <= max - 360.0 { deg += 360.0 }
    while deg > max { deg -= 360.0 }
    return deg
}

/// The time during `jdn` at which the Moon reaches `targetDegrees` of elongation from the Sun.
func searchMoonAgeTime(jdn: Jdn, targetDegrees: Double) -> Clock? {
    let start = jdn.toAstronomyTime(hourOfDay: 0)
    let end = (jdn + 1).toAstronomyTime(hourOfDay: 0)
    guard let found = search(t1: start, t2: end, toleranceSeconds: 1.0, { time in
        let d = eclipticGeoMoon(time).lon - sunPosition(time).elon
        return withMaxDegreeValue(floorMod(d, 360.0) - targetDegrees, 180.0)
    }) else { return nil }
    return clock(from: found, setIranTime: false)
}

/// The time during `jdn` at which the Moon's ecliptic longitude reaches `targetLon`.
///
/// - Parameter setIranTime: should only be used by tests and the "Iran time" setting.
func searchLunarLongitude(jdn: Jdn, targetLon: Double, setIranTime: Bool = false) -> Clock? {
    let startTime = jdn.toAstronomyTime(hourOfDay: 0, setIranTime: setIranTime)
    let endTime = startTime.addDays(1.0)
    guard let found = search(t1: startTime, t2: endTime, toleranceSeconds: 1.0, { time in
        withMaxDegreeValue(eclipticGeoMoon(time).lon - targetLon, 180.0)
    }) else { return nil }
    return clock(from: found, setIranTime: setIranTime)
}

private func clock(from time: AstroTime, setIranTime: Bool) -> Clock {
    var calendar = Foundation.Calendar(identifier: .gregorian)
    if setIranTime {
        calendar.timeZone = TimeZone(identifier: EventsRepository.iranTimeZoneIdentifier) ?? .current
    }
    let parts = calendar.dateComponents(
        [.hour, .minute, .second, .nanosecond], from: time.date)
    return Clock(
        hour: parts.hour ?? 0, minute: parts.minute ?? 0,
        second: parts.second ?? 0, nanosecond: parts.nanosecond ?? 0)
}

func moonInScorpioState(jdn: Jdn, setIranTime: Bool = false) -> MoonInScorpioState? {
    let end = isMoonInScorpio(jdn: jdn, hourOfDay: 0, setIranTime: setIranTime)
    let start = isMoonInScorpio(jdn: jdn + 1, hourOfDay: 0, setIranTime: setIranTime)
    switch (start, end) {
    case (true, true):
        let middayLongitude = lunarLongitude(jdn: jdn, setIranTime: setIranTime, hourOfDay: 12)
        return middayLongitude <= Zodiac.scorpio.tropicalRange[1] ? .borji : .falaki
    case (true, false):
        return .start(
            searchLunarLongitude(
                jdn: jdn, targetLon: Zodiac.scorpioRange.lowerBound, setIranTime: setIranTime)
                ?? .zero)
    case (false, true):
        return .end(
            searchLunarLongitude(
                jdn: jdn, targetLon: Zodiac.scorpioRange.upperBound, setIranTime: setIranTime)
                ?? .zero)
    case (false, false):
        return nil
    }
}

/// The tilt of the Moon's sunlit limb, in degrees, as seen by the observer.
///
/// https://github.com/cosinekitty/astronomy/blob/0547aaf/demo/csharp/camera/camera.cs#L98
func sunlitSideMoonTiltAngle(time: AstroTime, observer: Observer) -> Double {
    let moonEquator = equator(.moon, time, observer, .ofDate, .none)
    let sunEquator = equator(.sun, time, observer, .ofDate, .none)
    let moonHorizontal = horizon(
        time, observer, moonEquator.ra, moonEquator.dec, .none)
    let vec = rotationEqdHor(time, observer)
        .pivot(2, moonHorizontal.azimuth)
        .pivot(1, moonHorizontal.altitude)
        .rotate(sunEquator.vec)
    return radiansToDegrees(atan2(vec.z, vec.y))
}

extension Body {
    /// Localization key; the display name comes from the string catalog.
    var titleKey: String {
        switch self {
        case .mercury: "mercury"
        case .venus: "venus"
        case .earth: "earth"
        case .mars: "mars"
        case .jupiter: "jupiter"
        case .saturn: "saturn"
        case .uranus: "uranus"
        case .neptune: "neptune"
        case .pluto: "pluto"
        case .sun: "sun"
        case .moon: "moon"
        }
    }

    var symbol: String {
        switch self {
        case .sun: "☉"
        case .earth: "🜨"
        case .moon: "☽"
        case .mars: "♂"
        case .mercury: "☿"
        case .jupiter: "♃"
        case .venus: "♀"
        case .saturn: "♄"
        case .uranus: "⛢"
        case .neptune: "♆"
        case .pluto: "♇"
        }
    }
}
