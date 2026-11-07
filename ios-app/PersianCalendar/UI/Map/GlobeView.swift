import SwiftUI

/// A rotatable globe, drawn by projecting the world map onto a sphere.
struct GlobeView: View {
    @Environment(AppSettings.self) private var settings

    let time: AstroTime
    let showsNight: Bool

    @State private var longitude: Double = 0
    @State private var latitude: Double = 20
    @State private var dragStart: (latitude: Double, longitude: Double)?
    @State private var autoRotate = true

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - 4
            let projection = OrthographicProjection(
                centerLatitude: latitude,
                centerLongitude: longitude,
                radius: radius,
                center: CGPoint(x: size.width / 2, y: size.height / 2))

            let sphere = Path(
                ellipseIn: CGRect(
                    x: projection.center.x - radius, y: projection.center.y - radius,
                    width: radius * 2, height: radius * 2))

            // Ocean.
            context.fill(sphere, with: .color(Color.accentColor.opacity(0.25)))

            // Coastlines, each subpath projected and broken wherever it crosses the horizon.
            var land = Path()
            for line in GlobeGeometry.coastlines {
                var started = false
                for geoPoint in line {
                    if let point = projection.project(geoPoint) {
                        if started {
                            land.addLine(to: point)
                        } else {
                            land.move(to: point)
                            started = true
                        }
                    } else {
                        started = false
                    }
                }
            }
            context.stroke(land, with: .color(.secondary), lineWidth: 0.7)

            if showsNight { drawNight(&context, projection: projection, radius: radius) }

            // Limb.
            context.stroke(sphere, with: .color(.secondary.opacity(0.7)), lineWidth: 1)

            if let coordinates = settings.coordinates {
                let position = GlobeGeometry.GeoPoint(
                    latitude: coordinates.latitude, longitude: coordinates.longitude)
                if let point = projection.project(position) {
                    context.fill(
                        Path(
                            ellipseIn: CGRect(
                                x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
                        with: .color(.red))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .gesture(
            DragGesture()
                .onChanged { value in
                    autoRotate = false
                    if dragStart == nil { dragStart = (latitude, longitude) }
                    guard let start = dragStart else { return }
                    longitude = start.longitude - Double(value.translation.width) * 0.5
                    latitude = min(
                        max(start.latitude + Double(value.translation.height) * 0.5, -90), 90)
                }
                .onEnded { _ in dragStart = nil }
        )
        .task {
            // A slow idle spin, stopped as soon as the user takes hold of it.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard autoRotate else { continue }
                longitude = floorMod(longitude + 0.35 + 180, 360) - 180
            }
        }
        .accessibilityLabel("Globe")
    }

    /// Shade the night hemisphere.
    ///
    /// For a given latitude the Sun is up where `cos(H) > -tan(lat)tan(dec)`, so each latitude
    /// band's dark span has an exact longitude range. Emitting one band per degree with those
    /// exact endpoints gives a smooth terminator, where sampling a coarse lat/lon grid left a
    /// visible staircase.
    private func drawNight(
        _ context: inout GraphicsContext, projection: OrthographicProjection, radius: CGFloat
    ) {
        let subsolar = Terminator.subsolarPoint(time)
        let tanDec = tan(toRadians(subsolar.latitude))
        let bandHeight = 1.0
        /// How finely to subdivide each band's edges, so they follow the sphere's curvature.
        let longitudeStep = 4.0

        var night = Path()
        for latitude in stride(from: -90.0, to: 90.0, by: bandHeight) {
            let mid = latitude + bandHeight / 2
            let k = -tan(toRadians(mid)) * tanDec

            let halfSpan: Double
            if k <= -1 {
                continue  // Polar day: the whole band is lit.
            } else if k >= 1 {
                halfSpan = 180  // Polar night: the whole band is dark.
            } else {
                halfSpan = 180 - radiansToDegrees(acos(k))
            }
            guard halfSpan > 0 else { continue }

            // The dark arc is centred on the antisolar longitude.
            let antisolar = subsolar.longitude + 180
            let from = antisolar - halfSpan
            let to = antisolar + halfSpan

            var forward: [CGPoint] = []
            var backward: [CGPoint] = []
            var longitude = from
            while longitude < to {
                let next = Swift.min(longitude + longitudeStep, to)
                if let point = projection.project(
                    .init(latitude: latitude + bandHeight, longitude: longitude))
                {
                    forward.append(point)
                }
                if let point = projection.project(
                    .init(latitude: latitude, longitude: longitude))
                {
                    backward.append(point)
                }
                longitude = next
            }
            if let point = projection.project(
                .init(latitude: latitude + bandHeight, longitude: to))
            {
                forward.append(point)
            }
            if let point = projection.project(.init(latitude: latitude, longitude: to)) {
                backward.append(point)
            }

            guard forward.count + backward.count >= 3 else { continue }
            night.move(to: forward.first ?? backward.first!)
            for point in forward.dropFirst() { night.addLine(to: point) }
            for point in backward.reversed() { night.addLine(to: point) }
            night.closeSubpath()
        }
        context.fill(night, with: .color(.black.opacity(0.4)))
    }
}
