import Foundation

/// Placidus house cusps, the ascendant and the midheaven.
///
/// See also Swiss Ephemeris' https://github.com/jwmatthys/pd-swisseph/blob/master/swehouse.h
/// Compatibility with Placidus is desired, even though it breaks down at high latitudes.
/// The implementation started from
/// https://github.com/cosinekitty/astronomy/discussions/340#discussioncomment-8966532
/// for the ascendant and midheaven, then was simplified and extended to all twelve houses.
///
/// - Returns: the twelve cusps in degrees, house 1 (ascendant) first.
func houses(latitude: Double, longitude: Double, time: AstroTime) -> [Double] {
    // Row 1 of the ecliptic-to-equatorial rotation carries the obliquity's cos and sin.
    let row = rotationEctEqd(time).rot[1]
    let cosOb = row[1]
    let sinOb = row[2]
    let tanPhi = tan(toRadians(latitude))
    // Right ascension of the midheaven (MC).
    let ramcRad = toRadians((siderealTime(time) * 15 + longitude + 360)
        .truncatingRemainder(dividingBy: 360))

    var houses = [Double](repeating: 0, count: 12)

    houses[10] = solvePlacidusCusp(tanPhi, ramcRad, cosOb, sinOb, 1.0 / 3, isNocturnalCusp: false)
    houses[11] = solvePlacidusCusp(tanPhi, ramcRad, cosOb, sinOb, 2.0 / 3, isNocturnalCusp: false)
    houses[1] = solvePlacidusCusp(tanPhi, ramcRad, cosOb, sinOb, 2.0 / 3, isNocturnalCusp: true)
    houses[2] = solvePlacidusCusp(tanPhi, ramcRad, cosOb, sinOb, 1.0 / 3, isNocturnalCusp: true)
    houses[4] = (houses[10] + 180).truncatingRemainder(dividingBy: 360)
    houses[5] = (houses[11] + 180).truncatingRemainder(dividingBy: 360)
    houses[7] = (houses[1] + 180).truncatingRemainder(dividingBy: 360)
    houses[8] = (houses[2] + 180).truncatingRemainder(dividingBy: 360)

    let sinRamc = sin(ramcRad)
    let cosRamc = cos(ramcRad)
    // Midheaven
    let mc = (radiansToDegrees(atan2(sinRamc, cosRamc * cosOb)) + 360)
        .truncatingRemainder(dividingBy: 360)
    let dsc = (radiansToDegrees(atan2(-cosRamc, sinRamc * cosOb + tanPhi * sinOb)) + 360)
        .truncatingRemainder(dividingBy: 360)
    // Ascendant: the first house, and the most important one.
    houses[0] = (dsc + 180).truncatingRemainder(dividingBy: 360)
    houses[9] = mc
    // Nadir, or Imum Coeli (IC)
    houses[3] = (mc + 180).truncatingRemainder(dividingBy: 360)
    houses[6] = dsc
    return houses
}

private func solvePlacidusCusp(
    _ tanPhi: Double,
    _ ramcRad: Double,
    _ cosOb: Double,
    _ sinOb: Double,
    _ cuspRatio: Double,
    isNocturnalCusp: Bool
) -> Double {
    let referenceRaRad = ramcRad + (isNocturnalCusp ? .pi : 0)
    var y = sin(referenceRaRad)
    var x = cos(referenceRaRad) * cosOb
    // Eight iterations is comfortably more than enough for the accuracy needed.
    for _ in 0..<8 {
        // Declination (δ) of the current longitude guess (λ)
        let dec = y / (x * x + y * y).squareRoot() * sinOb
        // Ascensional difference
        let ad = asin(min(max(dec / (1 - dec * dec).squareRoot() * tanPhi, -1.0), 1.0))
        let requiredRa =
            referenceRaRad + (ad + .pi / (isNocturnalCusp ? -2 : 2)) * cuspRatio
        y = sin(requiredRa)
        x = cos(requiredRa) * cosOb
    }
    return (radiansToDegrees(atan2(y, x)) + 360).truncatingRemainder(dividingBy: 360)
}

/// Geocentric ecliptic longitude and distance of a body.
func geocentricLongitudeAndDistance(of body: Body, time: AstroTime) -> (
    longitude: Double, distance: Double
) {
    switch body {
    case .sun:
        let position = sunPosition(time)
        return (position.elon, position.vec.length())
    case .moon:
        let moon = eclipticGeoMoon(time)
        return (moon.lon, moon.dist)
    default:
        let ecliptic = equatorialToEcliptic(geoVector(body, time, .corrected))
        return (ecliptic.elon, ecliptic.vec.length())
    }
}

/// Whether the chart is diurnal — the Sun above the horizon, between ascendant and descendant.
func isDiurnal(houses: [Double], time: AstroTime) -> Bool {
    let sunLon = geocentricLongitudeAndDistance(of: .sun, time: time).longitude
    let ascendant = houses[0]
    let descendant = houses[6]
    return floorMod(sunLon - descendant, 360.0) < floorMod(ascendant - descendant, 360.0)
}
