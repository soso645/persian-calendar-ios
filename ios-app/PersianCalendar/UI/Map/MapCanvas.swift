import SwiftUI

/// Draws the world map and its overlays.
///
/// The bundled path data is authored on a 360x180 degree grid scaled by 16, so everything is drawn
/// in that space and scaled to fit once, which keeps the projection arithmetic in degrees.
struct MapCanvas: View {
    let mapType: MapType
    let showsGrid: Bool
    let showsQibla: Bool
    let coordinates: Coordinates?
    let time: AstroTime

    private static let scale: CGFloat = 16
    private static let mapWidth: CGFloat = 360 * scale
    private static let mapHeight: CGFloat = 180 * scale

    /// Parsing 250 KB of path data is slow enough to be worth doing once per process.
    private static let worldMap = SVGPath.loadResource("worldmap")
    private static let tectonicPlates = SVGPath.loadResource("tectonicplates")
    private static let timeZones = SVGPath.loadResource("timezones")

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / Self.mapWidth
            let scaleY = size.height / Self.mapHeight
            context.scaleBy(x: scaleX, y: scaleY)
            // The source paths overshoot the frame slightly (Antarctica runs a fraction of a
            // degree past the southern edge), so clip to the exact map rectangle.
            context.clip(
                to: Path(CGRect(x: 0, y: 0, width: Self.mapWidth, height: Self.mapHeight)))

            context.fill(
                Path(CGRect(x: 0, y: 0, width: Self.mapWidth, height: Self.mapHeight)),
                with: .color(Color(.systemBackground)))

            context.fill(Self.worldMap, with: .color(.secondary.opacity(0.55)))

            switch mapType {
            case .none:
                break
            case .dayNight:
                drawNightMask(&context)
            case .tectonicPlates:
                context.stroke(
                    Self.tectonicPlates, with: .color(.orange),
                    lineWidth: 2 / min(scaleX, scaleY))
            case .timeZones:
                context.stroke(
                    Self.timeZones, with: .color(.blue.opacity(0.6)),
                    lineWidth: 1.5 / min(scaleX, scaleY))
            }

            if showsGrid { drawGrid(&context, lineScale: min(scaleX, scaleY)) }
            if let coordinates {
                if showsQibla { drawQibla(&context, from: coordinates, lineScale: min(scaleX, scaleY)) }
                drawPin(&context, at: coordinates, lineScale: min(scaleX, scaleY))
            }
        }
        .drawingGroup()
        .accessibilityLabel("World map")
    }

    // MARK: - Projection

    private static func point(latitude: Double, longitude: Double) -> CGPoint {
        CGPoint(
            x: (longitude + 180) * scale,
            y: (90 - latitude) * scale)
    }

    // MARK: - Overlays

    /// Shade the hemisphere where the Sun is below the horizon.
    private func drawNightMask(_ context: inout GraphicsContext) {
        let subsolar = Terminator.subsolarPoint(time)

        var path = Path()
        // Trace the terminator across every longitude, one degree at a time.
        var first = true
        for degrees in stride(from: -180.0, through: 180.0, by: 1.0) {
            let latitude = Terminator.terminatorLatitude(
                longitude: degrees, subsolar: subsolar)
            let point = Self.point(latitude: latitude, longitude: degrees)
            if first {
                path.move(to: point)
                first = false
            } else {
                path.addLine(to: point)
            }
        }
        // Close along whichever pole is in darkness: the one away from the subsolar latitude.
        let nightIsNorth = subsolar.latitude < 0
        let poleY: CGFloat = nightIsNorth ? 0 : Self.mapHeight
        path.addLine(to: CGPoint(x: Self.mapWidth, y: poleY))
        path.addLine(to: CGPoint(x: 0, y: poleY))
        path.closeSubpath()

        context.fill(path, with: .color(.black.opacity(0.45)))

        // Mark the subsolar point itself.
        let sun = Self.point(latitude: subsolar.latitude, longitude: subsolar.longitude)
        let radius: CGFloat = 5 * Self.scale
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: sun.x - radius, y: sun.y - radius,
                    width: radius * 2, height: radius * 2)),
            with: .color(.yellow))
    }

    private func drawGrid(_ context: inout GraphicsContext, lineScale: CGFloat) {
        var minor = Path()
        // Every 15° of longitude is one hour of time; every 15° of latitude keeps it square.
        for degrees in stride(from: -180.0, through: 180.0, by: 15.0) {
            let x = (degrees + 180) * Self.scale
            minor.move(to: CGPoint(x: x, y: 0))
            minor.addLine(to: CGPoint(x: x, y: Self.mapHeight))
        }
        for degrees in stride(from: -90.0, through: 90.0, by: 15.0) {
            let y = (90 - degrees) * Self.scale
            minor.move(to: CGPoint(x: 0, y: y))
            minor.addLine(to: CGPoint(x: Self.mapWidth, y: y))
        }
        context.stroke(minor, with: .color(.gray.opacity(0.35)), lineWidth: 1 / lineScale)

        var major = Path()
        // Equator, and the tropics and polar circles.
        for latitude in [0.0, 23.4394, -23.4394, 66.5606, -66.5606] {
            let y = (90 - latitude) * Self.scale
            major.move(to: CGPoint(x: 0, y: y))
            major.addLine(to: CGPoint(x: Self.mapWidth, y: y))
        }
        context.stroke(major, with: .color(.gray.opacity(0.7)), lineWidth: 1.5 / lineScale)
    }

    /// The great-circle route to the Kaaba, which is the true qibla direction.
    private func drawQibla(
        _ context: inout GraphicsContext, from coordinates: Coordinates, lineScale: CGFloat
    ) {
        let points = coordinates.earthPosition.intermediatePoints(to: .qibla, count: 64)
        var path = Path()
        var previous: CGPoint?
        for position in points {
            let point = Self.point(
                latitude: position.latitude, longitude: position.longitude)
            // A great circle can cross the antimeridian; break the line rather than drawing a
            // spurious stroke straight back across the map.
            if let previous, abs(point.x - previous.x) > Self.mapWidth / 2 {
                path.move(to: point)
            } else if previous == nil {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
            previous = point
        }
        context.stroke(
            path, with: .color(.green),
            style: StrokeStyle(lineWidth: 2 / lineScale, dash: [6 / lineScale, 4 / lineScale]))

        let kaaba = Self.point(
            latitude: EarthPosition.qibla.latitude, longitude: EarthPosition.qibla.longitude)
        let size: CGFloat = 4 * Self.scale
        context.fill(
            Path(
                CGRect(
                    x: kaaba.x - size / 2, y: kaaba.y - size / 2, width: size, height: size)),
            with: .color(.green))
    }

    private func drawPin(
        _ context: inout GraphicsContext, at coordinates: Coordinates, lineScale: CGFloat
    ) {
        let point = Self.point(
            latitude: coordinates.latitude, longitude: coordinates.longitude)
        let radius: CGFloat = 4 * Self.scale
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: point.x - radius, y: point.y - radius,
                    width: radius * 2, height: radius * 2)),
            with: .color(.red))
        context.stroke(
            Path(
                ellipseIn: CGRect(
                    x: point.x - radius, y: point.y - radius,
                    width: radius * 2, height: radius * 2)),
            with: .color(.white), lineWidth: 1.5 / lineScale)
    }
}
