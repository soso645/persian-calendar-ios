import SwiftUI

/// A compass rose with an optional qibla marker.
struct CompassScreen: View {
    @Environment(AppSettings.self) private var settings
    @State private var motion = MotionProvider()

    private var qiblaHeading: Double? {
        guard settings.showQiblaInCompass, let coordinates = settings.coordinates else {
            return nil
        }
        return coordinates.qiblaHeading
    }

    var body: some View {
        VStack(spacing: 20) {
            if let heading = motion.heading {
                CompassRose(heading: heading, qiblaHeading: qiblaHeading)
                    .frame(maxWidth: 320, maxHeight: 320)

                Text(settings.numeral.format(Int(heading.rounded())) + "°")
                    .font(.system(.largeTitle, design: .rounded))
                    .monospacedDigit()

                Text(motion.isTrueNorth ? "True north" : "Magnetic north")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let qiblaHeading {
                    Label(
                        "Qibla \(settings.numeral.format(Int(qiblaHeading.rounded())))°",
                        systemImage: "location.north.line")
                        .font(.callout)
                        .foregroundStyle(.green)
                } else if settings.showQiblaInCompass {
                    Text("Set a location in Settings to see the qibla direction.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ContentUnavailableView(
                    motion.authorizationDenied ? "Location access needed" : "No compass",
                    systemImage: "location.slash",
                    description: Text(
                        motion.authorizationDenied
                            ? "Allow location access to use true north."
                            : "This device has no magnetometer, or it is still warming up."))
            }
        }
        .padding()
        .navigationTitle("Compass")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { motion.startHeading(trueNorth: settings.trueNorthInCompass) }
        .onDisappear { motion.stopHeading() }
    }
}

/// The rotating dial.
private struct CompassRose: View {
    let heading: Double
    let qiblaHeading: Double?

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 12

            context.stroke(
                Path(ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2)),
                with: .color(.secondary.opacity(0.4)), lineWidth: 2)

            // Tick marks every 15 degrees, longer every 90.
            for degree in stride(from: 0, to: 360, by: 15) {
                let angle = toRadians(Double(degree) - heading - 90)
                let isCardinal = degree % 90 == 0
                let inner = radius - (isCardinal ? 18 : 8)
                var path = Path()
                path.move(to: CGPoint(
                    x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                path.addLine(to: CGPoint(
                    x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                context.stroke(
                    path,
                    with: .color(isCardinal ? .primary : .secondary.opacity(0.5)),
                    lineWidth: isCardinal ? 2 : 1)
            }

            // North needle.
            let northAngle = toRadians(-heading - 90)
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: CGPoint(
                x: center.x + cos(northAngle) * (radius - 24),
                y: center.y + sin(northAngle) * (radius - 24)))
            context.stroke(needle, with: .color(.red), lineWidth: 3)

            if let qiblaHeading {
                let qiblaAngle = toRadians(qiblaHeading - heading - 90)
                var marker = Path()
                marker.move(to: center)
                marker.addLine(to: CGPoint(
                    x: center.x + cos(qiblaAngle) * (radius - 24),
                    y: center.y + sin(qiblaAngle) * (radius - 24)))
                context.stroke(
                    marker, with: .color(.green),
                    style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
            }

            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                with: .color(.primary))
        }
        .accessibilityLabel("Compass showing \(Int(heading.rounded())) degrees")
    }
}
