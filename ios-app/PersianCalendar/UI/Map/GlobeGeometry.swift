import CoreGraphics
import SwiftUI

/// The world map as geographic coordinates, ready to be projected onto a sphere.
///
/// The Android app renders its globe with OpenGL ES and AGSL shaders. Rather than port those to
/// Metal, this projects the same coastline paths orthographically and draws them with `Canvas` —
/// the same picture, from the same data, without a shader pipeline to maintain.
enum GlobeGeometry {
    /// A point on the sphere in degrees.
    struct GeoPoint {
        let latitude: Double
        let longitude: Double
    }

    /// Coastlines as separate polylines, so subpaths aren't joined by stray segments.
    ///
    /// Built once: extracting and converting the whole world map is far too slow to redo per
    /// frame, whereas projecting the result is cheap.
    static let coastlines: [[GeoPoint]] = extractSubpaths(SVGPath.loadResource("worldmap"))

    private static func extractSubpaths(_ path: Path) -> [[GeoPoint]] {
        var result: [[GeoPoint]] = []
        var current: [GeoPoint] = []

        func convert(_ point: CGPoint) -> GeoPoint {
            // Inverse of the equirectangular projection the path data is authored in.
            GeoPoint(
                latitude: 90 - Double(point.y) / 16,
                longitude: Double(point.x) / 16 - 180)
        }

        path.forEach { element in
            switch element {
            case let .move(to: point):
                if current.count > 1 { result.append(current) }
                current = [convert(point)]
            case let .line(to: point):
                current.append(convert(point))
            case let .quadCurve(to: point, control: _):
                current.append(convert(point))
            case let .curve(to: point, control1: _, control2: _):
                current.append(convert(point))
            case .closeSubpath:
                if let first = current.first { current.append(first) }
                if current.count > 1 { result.append(current) }
                current = []
            }
        }
        if current.count > 1 { result.append(current) }
        return result
    }
}

/// Orthographic projection: the view of a sphere from infinitely far away.
struct OrthographicProjection {
    /// Centre of the visible hemisphere, in degrees.
    let centerLatitude: Double
    let centerLongitude: Double
    let radius: CGFloat
    let center: CGPoint

    /// Project a point, or nil when it falls on the far side of the sphere.
    func project(_ point: GlobeGeometry.GeoPoint) -> CGPoint? {
        let lat = toRadians(point.latitude)
        let lon = toRadians(point.longitude - centerLongitude)
        let lat0 = toRadians(centerLatitude)

        // cos(c) is the cosine of the angular distance from the projection centre; negative means
        // the point is over the horizon.
        let cosC = sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(lon)
        guard cosC >= 0 else { return nil }

        let x = cos(lat) * sin(lon)
        let y = cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(lon)
        return CGPoint(
            x: center.x + radius * CGFloat(x),
            // Screen y grows downwards, so the northward component is negated.
            y: center.y - radius * CGFloat(y))
    }
}
