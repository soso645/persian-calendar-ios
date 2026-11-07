import SwiftUI

/// A bubble level driven by the device's attitude.
struct LevelScreen: View {
    @State private var motion = MotionProvider()

    var body: some View {
        VStack(spacing: 24) {
            if motion.isLevelAvailable {
                BubbleLevel(roll: motion.roll, pitch: motion.pitch)
                    .frame(maxWidth: 300, maxHeight: 300)

                HStack(spacing: 32) {
                    LabeledContent("Roll") {
                        Text("\(Int(motion.roll.rounded()))°").monospacedDigit()
                    }
                    LabeledContent("Pitch") {
                        Text("\(Int(motion.pitch.rounded()))°").monospacedDigit()
                    }
                }
                .font(.headline)
            } else {
                ContentUnavailableView(
                    "No motion sensors",
                    systemImage: "gyroscope",
                    description: Text("This device cannot report its attitude."))
            }
        }
        .padding()
        .navigationTitle("Level")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { motion.startLevel() }
        .onDisappear { motion.stopLevel() }
    }
}

private struct BubbleLevel: View {
    let roll: Double
    let pitch: Double

    /// Tilt beyond this many degrees pins the bubble to the rim.
    private let maxTilt = 30.0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 8

            for fraction in [1.0, 0.66, 0.33] {
                let r = radius * fraction
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .color(.secondary.opacity(0.35)), lineWidth: 1)
            }

            var crosshair = Path()
            crosshair.move(to: CGPoint(x: center.x - radius, y: center.y))
            crosshair.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            crosshair.move(to: CGPoint(x: center.x, y: center.y - radius))
            crosshair.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            context.stroke(crosshair, with: .color(.secondary.opacity(0.35)), lineWidth: 1)

            let offsetX = (roll / maxTilt).clamped(to: -1...1) * radius
            let offsetY = (pitch / maxTilt).clamped(to: -1...1) * radius
            let bubble = CGPoint(x: center.x + offsetX, y: center.y + offsetY)
            let isLevel = abs(roll) < 1 && abs(pitch) < 1

            context.fill(
                Path(ellipseIn: CGRect(
                    x: bubble.x - 18, y: bubble.y - 18, width: 36, height: 36)),
                with: .color(isLevel ? .green : .accentColor))
        }
        .accessibilityLabel("Bubble level, roll \(Int(roll)) degrees, pitch \(Int(pitch)) degrees")
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
