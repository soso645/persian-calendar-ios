import Foundation

/// Ecliptic longitude of a fixed star, from its J2000 ICRS equatorial coordinates.
///
/// - Parameters:
///   - raHours: right ascension in hours.
///   - decDegrees: declination in degrees.
private func starEclipticLon(raHours: Double, decDegrees: Double, time: AstroTime) -> Double {
    let ra = raHours * (.pi / 12.0)
    let dec = decDegrees * (.pi / 180.0)
    let cosD = cos(dec)
    let vector = AstroVector(
        x: cosD * cos(ra), y: cosD * sin(ra), z: sin(dec), t: time)
    return equatorialToEcliptic(vector).elon
}

/// Hatysa (ι Orionis Aa) — نير السيف, "Bright one of the Sword".
///
/// https://en.wikipedia.org/wiki/Iota_Orionis — J2000 ICRS: HIP 26241,
/// RA 05h 35m 25.982s → 5.59055h, Dec −05° 54′ 35.6″ → −5.9099°
func nairAlSaif(_ time: AstroTime) -> Double {
    starEclipticLon(raHours: 5.59055, decDegrees: -5.9099, time: time)
}

/// Nu Ursae Majoris — الأولى الشمالية, "The First Northern [Spring]".
///
/// https://en.wikipedia.org/wiki/Nu_Ursae_Majoris — J2000 ICRS: HIP 55219,
/// RA 11h 18m 28.737s → 11.3080h, Dec +33° 05′ 39.51″ → +33.0943°
func alulaBorealis(_ time: AstroTime) -> Double {
    starEclipticLon(raHours: 11.3080, decDegrees: 33.0943, time: time)
}

/// The lunar apogee, known in this tradition as the "black moon" (Lilith).
///
/// Formula from
/// https://ftp.space.dtu.dk/pub/DTU10/DTU10_TIDEMODEL/SOFTWARE/test_perth3.f
func meanApogee(_ time: AstroTime) -> Double {
    let t = time.tt / 36525.0
    let meanPerigee = ((-1.249172e-5 * t - 1.032e-2) * t + 4069.0137287) * t + 83.3532465
    return floorMod(meanPerigee + 180, 360.0)
}

/// The Moon's ascending node (رأس التنين).
///
/// Interpolates the true node between the nearest bracketing crossings rather than using the mean
/// polynomial: at an ascending crossing the node longitude equals the Moon's longitude, and at a
/// descending crossing it is the Moon's longitude minus 180°. Using both kinds halves the interval
/// to about 13.6 days, which is what makes the result accurate enough to match printed tables.
func meanAscendingNode(_ time: AstroTime) -> Double {
    var previousLon = Double.nan
    var previousTt = Double.nan

    for event in moonNodeSequence(after: time.addDays(-16.0)) {
        let moonLon = eclipticGeoMoon(event.time).lon
        let nodeLon =
            event.kind == .ascending ? moonLon : floorMod(moonLon - 180.0, 360.0)

        if event.time.tt > time.tt {
            if previousLon.isNaN { break }
            let fraction = (time.tt - previousTt) / (event.time.tt - previousTt)
            // Normalize the step into [-180, 180] so retrograde motion across 0°/360° behaves.
            let delta = floorMod(nodeLon - previousLon + 180, 360.0) - 180
            return floorMod(previousLon + fraction * delta, 360.0)
        }
        previousLon = nodeLon
        previousTt = event.time.tt
    }

    // Fallback: the mean ascending node polynomial, same source as `meanApogee`.
    let t = time.tt / 36525.0
    return floorMod(((2.22222e-6 * t + 2.0708e-3) * t - 1934.136261) * t + 125.04452, 360.0)
}
