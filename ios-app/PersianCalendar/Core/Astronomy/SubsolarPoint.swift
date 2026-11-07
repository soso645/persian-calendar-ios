import Foundation

/// Where the Sun is directly overhead, and the day/night terminator derived from it.
enum Terminator {
    /// Latitude and longitude of the subsolar point, in degrees.
    static func subsolarPoint(_ time: AstroTime) -> (latitude: Double, longitude: Double) {
        // Equatorial coordinates of date, from an observer at the origin — the subsolar latitude
        // is the Sun's declination, and its longitude follows from the sidereal time.
        let equatorial = equator(.sun, time, Observer(0, 0, 0), .ofDate, .corrected)
        let gmstHours = siderealTime(time)
        let longitude = floorMod((equatorial.ra - gmstHours) * 15 + 180, 360) - 180
        return (equatorial.dec, longitude)
    }

    /// The terminator's latitude at a given longitude, in degrees.
    ///
    /// Solves `sin(φ)sin(δ) + cos(φ)cos(δ)cos(λ − λ₀) = 0`, the locus where the Sun sits exactly
    /// on the horizon.
    static func terminatorLatitude(
        longitude: Double, subsolar: (latitude: Double, longitude: Double)
    ) -> Double {
        let declination = toRadians(subsolar.latitude)
        // Near an equinox the declination approaches zero and the terminator becomes a meridian;
        // clamp so the tangent stays finite.
        let tanDec = tan(declination)
        let safeTanDec = abs(tanDec) < 1e-6 ? (tanDec < 0 ? -1e-6 : 1e-6) : tanDec
        let hourAngle = toRadians(longitude - subsolar.longitude)
        return radiansToDegrees(atan(-cos(hourAngle) / safeTanDec))
    }

    /// Whether a point is in daylight.
    static func isDaylight(
        latitude: Double, longitude: Double, subsolar: (latitude: Double, longitude: Double)
    ) -> Bool {
        let lat = toRadians(latitude)
        let dec = toRadians(subsolar.latitude)
        let hourAngle = toRadians(longitude - subsolar.longitude)
        let sinAltitude = sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(hourAngle)
        return sinAltitude > 0
    }
}
