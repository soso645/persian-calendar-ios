import Foundation

/// A point on the Earth's surface, with great-circle helpers.
struct EarthPosition: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    /// The Kaaba, the qibla direction's target.
    static let qibla = EarthPosition(latitude: 21.422522, longitude: 39.826181)

    /// Mean Earth radius in metres, as used by the WGS84-adjacent spherical approximation.
    private static let earthRadius = 6_371_008.8

    func toCoordinates() -> Coordinates {
        Coordinates(latitude: latitude, longitude: longitude, elevation: 0)
    }

    /// Great-circle distance in metres and the initial bearing in degrees to `target`.
    ///
    /// Replaces Android's `Location.distanceBetween`.
    func heading(to target: EarthPosition) -> (metres: Double, heading: Double) {
        let φ1 = toRadians(latitude)
        let φ2 = toRadians(target.latitude)
        let Δφ = φ2 - φ1
        let Δλ = toRadians(target.longitude - longitude)

        let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        let distance = 2 * atan2(sqrt(a), sqrt(1 - a)) * Self.earthRadius

        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let bearing = radiansToDegrees(atan2(y, x)).truncatingRemainder(dividingBy: 360)

        return (distance, bearing < 0 ? bearing + 360 : bearing)
    }

    /// Points along the great circle to `target`, inclusive of both ends.
    ///
    /// Ported from https://www.movable-type.co.uk/scripts/latlong.html (MIT).
    func intermediatePoints(to target: EarthPosition, count: Int) -> [EarthPosition] {
        let φ1 = toRadians(latitude)
        let λ1 = toRadians(longitude)
        let φ2 = toRadians(target.latitude)
        let λ2 = toRadians(target.longitude)
        let Δφ = φ2 - φ1
        let Δλ = λ2 - λ1
        let cosφ1 = cos(φ1), cosφ2 = cos(φ2)
        let cosλ1 = cos(λ1), cosλ2 = cos(λ2)
        let sinλ1 = sin(λ1), sinλ2 = sin(λ2)
        let sinφ1 = sin(φ1), sinφ2 = sin(φ2)
        let a = sin(Δφ / 2) * sin(Δφ / 2) + cosφ1 * cosφ2 * sin(Δλ / 2) * sin(Δλ / 2)
        let δ = 2 * atan2(sqrt(a), sqrt(1 - a))
        let sinδ = sin(δ)
        guard sinδ != 0 else { return [self] }

        return (0...count).map { index in
            let fraction = Double(index) / Double(count)
            let A = sin((1 - fraction) * δ) / sinδ
            let B = sin(fraction * δ) / sinδ
            let x = A * cosφ1 * cosλ1 + B * cosφ2 * cosλ2
            let y = A * cosφ1 * sinλ1 + B * cosφ2 * sinλ2
            let z = A * sinφ1 + B * sinφ2
            return EarthPosition(
                latitude: radiansToDegrees(atan2(z, (x * x + y * y).squareRoot())),
                longitude: radiansToDegrees(atan2(y, x)))
        }
    }
}

extension Coordinates {
    var earthPosition: EarthPosition {
        EarthPosition(latitude: latitude, longitude: longitude)
    }

    /// Compass bearing to the Kaaba, in degrees from true north.
    var qiblaHeading: Double {
        earthPosition.heading(to: .qibla).heading
    }
}
