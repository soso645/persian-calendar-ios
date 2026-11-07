import Foundation

/// A classical planet with its traditional astrological character.
struct Planet: Hashable, Sendable {
    let body: Body
    let en: String
    let fa: String
}

/// The Chaldean order, which governs both the planetary hours and the days of the week.
///
/// https://en.wikipedia.org/wiki/Planetary_hours
let chaldeanOrder: [Planet] = [
    Planet(body: .saturn, en: "Greatest Inauspicious", fa: "نحس اکبر"),
    Planet(body: .jupiter, en: "Greatest Auspicious", fa: "سعد اکبر"),
    Planet(body: .mars, en: "Lesser Inauspicious", fa: "نحس اصغر"),
    Planet(body: .sun, en: "Auspicious", fa: "سعد"),
    Planet(body: .venus, en: "Lesser Auspicious", fa: "سعد اصغر"),
    Planet(body: .mercury, en: "Mixed", fa: "ممترج"),
    Planet(body: .moon, en: "Ascendant", fa: "طالع"),
]

/// The spheres as used by the Astronomy screen's geocentric mode — the reverse of the Chaldean
/// order, minus the two already drawn.
///
/// سنایی، فی صفة الافلاک:
/// فلک تاسع است بر ز افلاک - کین فلکها بود درو چو مغاک
/// فلک ثامن است جای بروج - واندر آن هفت را دخول و خروج
let geocentricPlanetsList: [Body] =
    chaldeanOrder.reversed().map(\.body).filter { $0 != .moon && $0 != .sun }

/// One planetary hour: a twelfth of the day or of the night.
struct PlanetaryHourRow: Hashable, Sendable {
    let planet: Planet
    /// True for the twelve daylight hours, false for the twelve night ones.
    let isDay: Bool
    let from: Clock
    let to: Clock
    /// True when `now` falls inside this hour.
    let upcoming: Bool
}

/// Which planet rules the day, as an index into ``chaldeanOrder``.
func chaldeanIndex(from jdn: Jdn) -> Int {
    // Note how closely the weekday names track their ruling planets.
    let ruledBy: Body =
        switch jdn.weekDay {
        case .saturday: .saturn
        case .sunday: .sun
        case .monday: .moon
        case .tuesday: .mars
        case .wednesday: .mercury
        case .thursday: .jupiter
        case .friday: .venus
        }
    return chaldeanOrder.firstIndex { $0.body == ruledBy } ?? 0
}

/// The twelve day and twelve night planetary hours covering `now`.
///
/// Daylight is split into twelve equal parts between sunrise and sunset, and the night into twelve
/// between sunset and the next sunrise — so these hours are only 60 minutes long at the equinoxes.
///
/// - Parameters:
///   - now: Unix milliseconds.
///   - prayTimesForDay: sunrise and sunset for a day offset of -1, 0 or +1 from `now`.
///   - isToday: only then can an hour be marked as current.
func planetaryHours(
    now: Int,
    jdnForDayOffset: (Int) -> Jdn,
    sunriseSunset: (Int) -> (sunrise: Double, sunset: Double),
    isToday: Bool
) -> [PlanetaryHourRow] {
    var calendar = Foundation.Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let nowDate = Date(timeIntervalSince1970: Double(now) / 1000)
    let parts = calendar.dateComponents([.hour, .minute, .second], from: nowDate)
    let nowClock =
        Clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0, second: parts.second ?? 0).value
        + 24.0

    let dayOffsets = [-1, 0, 1]
    let chaldeanIndices = dayOffsets.map { chaldeanIndex(from: jdnForDayOffset($0)) }
    // Flattened as [sunrise(-1), sunset(-1), sunrise(0), sunset(0), sunrise(1), sunset(1)],
    // each shifted into a continuous 72-hour timeline.
    let times: [Double] = dayOffsets.enumerated().flatMap { index, offset -> [Double] in
        let value = sunriseSunset(offset)
        return [value.sunrise + Double(index) * 24, value.sunset + Double(index) * 24]
    }

    guard let firstAfterNow = times.enumerated().first(where: { $0.offset % 2 == 0 && nowClock < $0.element })
    else { return [] }
    let currentDayIndex = (firstAfterNow.offset / 2) - 1
    guard currentDayIndex >= 0 else { return [] }

    var result: [PlanetaryHourRow] = []
    for index in 1..<times.count {
        let previous = times[index - 1]
        let clock = times[index]
        let dayIndex = (index - 1) / 2
        let isDay = index % 2 == 1
        let groupOffset = ((index - 1) % 2) * 12
        let distance = (clock - previous) / 12
        guard dayIndex == currentDayIndex else { continue }
        let chaldean = chaldeanIndices[dayIndex]
        for hour in 0..<12 {
            let from = previous + distance * Double(hour)
            let to = previous + distance * Double(hour + 1)
            let planet = chaldeanOrder[(chaldean + hour + groupOffset) % chaldeanOrder.count]
            result.append(
                PlanetaryHourRow(
                    planet: planet,
                    isDay: isDay,
                    from: Clock(from.truncatingRemainder(dividingBy: 24)),
                    to: Clock(to.truncatingRemainder(dividingBy: 24)),
                    upcoming: isToday && nowClock >= from && nowClock <= to))
        }
    }
    return result
}
