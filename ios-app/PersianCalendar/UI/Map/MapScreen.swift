import SwiftUI

/// An equirectangular world map with optional overlays.
///
/// The Android original draws this with a `Canvas` over the same SVG path data and offers a dozen
/// overlay modes, several of which (magnetic field, crescent visibility) depend on Android-only
/// APIs. This port keeps the overlays that carry over: the day/night terminator, tectonic plates
/// and time zones.
struct MapScreen: View {
    @Environment(AppSettings.self) private var settings

    @State private var mapType: MapType = .dayNight
    @State private var showsGrid = false
    @State private var showsQibla = true
    @State private var isGlobe = false
    @State private var date = Date()

    /// The path data is authored against a 360x180 degree grid scaled by 16.
    private static let scale: CGFloat = 16
    private static let mapSize = CGSize(width: 360 * scale, height: 180 * scale)

    private var time: AstroTime {
        AstroTime.fromMillisecondsSince1970(Int(date.timeIntervalSince1970 * 1000))
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isGlobe {
                    GlobeView(time: time, showsNight: mapType == .dayNight)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                } else {
                    MapCanvas(
                        mapType: mapType,
                        showsGrid: showsGrid,
                        showsQibla: showsQibla && settings.coordinates != nil,
                        coordinates: settings.coordinates,
                        time: time)
                        .aspectRatio(2, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }
            .background(Color(.secondarySystemBackground))

            List {
                Toggle("Globe", isOn: $isGlobe)
                Picker("Overlay", selection: $mapType) {
                    ForEach(MapType.allCases) { type in
                        Text(type.localizedTitle(settings.language)).tag(type)
                    }
                }
                if !isGlobe {
                    Toggle("Grid", isOn: $showsGrid)
                    if settings.coordinates != nil {
                        Toggle("Qibla line", isOn: $showsQibla)
                    }
                }
                if mapType == .dayNight {
                    DatePicker("Time", selection: $date)
                    LabeledContent("Subsolar point") {
                        let point = Terminator.subsolarPoint(time)
                        Text(
                            formatAngle(abs(point.latitude), numeral: settings.numeral)
                                + (point.latitude >= 0 ? "N " : "S ")
                                + formatAngle(abs(point.longitude), numeral: settings.numeral)
                                + (point.longitude >= 0 ? "E" : "W"))
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The overlays this port supports.
enum MapType: String, CaseIterable, Identifiable, Sendable {
    case none
    case dayNight
    case timeZones
    case tectonicPlates

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.none, .fa): "هیچ‌کدام"
        case (.none, .ar): "لا شيء"
        case (.none, .en): "None"
        case (.dayNight, .fa): "شب و روز"
        case (.dayNight, .ar): "الليل والنهار"
        case (.dayNight, .en): "Day and night"
        case (.timeZones, .fa): "گستره‌های زمانی"
        case (.timeZones, .ar): "المناطق الزمنية"
        case (.timeZones, .en): "Time zones"
        case (.tectonicPlates, .fa): "صفحه‌های زمین‌ساخت"
        case (.tectonicPlates, .ar): "الصفائح التكتونية"
        case (.tectonicPlates, .en): "Tectonic plates"
        }
    }
}
