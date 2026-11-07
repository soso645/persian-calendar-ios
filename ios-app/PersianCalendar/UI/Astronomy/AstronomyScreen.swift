import SwiftUI

/// Sun and Moon information for a chosen day: phase, zodiac positions, and season.
struct AstronomyScreen: View {
    @Environment(AppSettings.self) private var settings

    @State private var jdn = Jdn.today()

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    private var time: AstroTime { jdn.toAstronomyTime(hourOfDay: 12) }

    private var sunLongitude: Double { sunPosition(time).elon }
    private var moonLongitude: Double { eclipticGeoMoon(time).lon }
    private var lunarAge: LunarAge {
        LunarAge.fromDegrees(moonLongitude - sunLongitude)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        jdn = jdn - 1
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .buttonStyle(.borderless)

                    Spacer()
                    Text(formatter.formatFullDate(jdn, calendar: settings.mainCalendar))
                        .font(.headline)
                    Spacer()

                    Button {
                        jdn = jdn + 1
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Section("Moon") {
                // The phase name sits with the emoji; the numbers get their own rows so their
                // values line up with the rest of the section rather than floating mid-card.
                HStack(spacing: 12) {
                    Text(lunarAge.toPhase().emoji(coordinates: settings.coordinates))
                        .font(.system(size: 44))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    Text(phaseTitle)
                        .font(.headline)
                    Spacer(minLength: 0)
                }
                LabeledContent("Age") {
                    Text(settings.numeral.format(String(format: "%.1f", lunarAge.days)) + " d")
                }
                LabeledContent("Illumination") {
                    Text(
                        settings.numeral.format(
                            Int((lunarAge.absolutePhaseValue * 100).rounded())) + "%")
                }
                LabeledContent("Distance") {
                    Text(
                        settings.numeral.formatLongNumber(Int(libration(time).distKm.rounded()))
                            + " km")
                }
                LabeledContent("Zodiac (tropical)") {
                    Text(zodiacLabel(Zodiac.fromTropical(moonLongitude)))
                }
                LabeledContent("Zodiac (IAU)") {
                    Text(zodiacLabel(Zodiac.fromIau(moonLongitude)))
                }
                if settings.showMoonInScorpio, let state = moonInScorpioState(jdn: jdn) {
                    LabeledContent("Moon in Scorpio") { Text(scorpioLabel(state)) }
                }
            }

            Section("Sun") {
                LabeledContent("Ecliptic longitude") {
                    Text(settings.numeral.format(String(format: "%.2f", sunLongitude)) + "°")
                }
                LabeledContent("Zodiac (tropical)") {
                    Text(zodiacLabel(Zodiac.fromTropical(sunLongitude)))
                }
                LabeledContent("Season") { Text(seasonLabel) }
                if let coordinates = settings.coordinates {
                    let observer = coordinates.toObserver()
                    let dayStart = jdn.toAstronomyTime(hourOfDay: 0)
                    if let sunrise = searchRiseSet(.sun, observer, .rise, dayStart, 1) {
                        LabeledContent("Sunrise") { Text(clockText(sunrise)) }
                    }
                    if let sunset = searchRiseSet(.sun, observer, .set, dayStart, 1) {
                        LabeledContent("Sunset") { Text(clockText(sunset)) }
                    }
                }
            }

            Section("Year") {
                LabeledContent("Animal year") {
                    Text(animalYearLabel)
                }
            }

            // The chart is a specialist feature, so it stays behind the astronomical-features
            // switch and needs a location to be meaningful.
            if settings.astronomicalFeatures, let coordinates = settings.coordinates {
                chartSection(coordinates)
            }
        }
        .navigationTitle("Astronomy")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func chartSection(_ coordinates: Coordinates) -> some View {
        let cusps = houses(
            latitude: coordinates.latitude, longitude: coordinates.longitude, time: time)
        let ascendant = cusps[0]
        let diurnal = isDiurnal(houses: cusps, time: time)

        Section("Chart") {
            LabeledContent("Ascendant") { Text(cuspLabel(ascendant)) }
            LabeledContent("Midheaven") { Text(cuspLabel(cusps[9])) }
            LabeledContent("Chart type") {
                Text(diurnal ? "Diurnal" : "Nocturnal")
            }
        }

        Section("Points") {
            LabeledContent("Black moon") { Text(cuspLabel(meanApogee(time))) }
            LabeledContent("Ascending node") { Text(cuspLabel(meanAscendingNode(time))) }
            LabeledContent("Nair al-Saif") { Text(cuspLabel(nairAlSaif(time))) }
            LabeledContent("Alula Borealis") { Text(cuspLabel(alulaBorealis(time))) }
        }

        Section("Lots") {
            ForEach(Lot.allCases, id: \.self) { lot in
                let longitude = lot.calculate(
                    ascendant: ascendant, isDiurnal: diurnal, time: time)
                LabeledContent(lot.title(settings.language)) {
                    Text(cuspLabel(longitude))
                }
            }
        }
    }

    /// A longitude rendered as its sign plus the degrees within that sign.
    private func cuspLabel(_ longitude: Double) -> String {
        let zodiac = Zodiac.fromTropical(longitude)
        let withinSign = longitude - Double(zodiac.rawValue) * 30
        return "\(zodiac.symbol) "
            + formatAngle(withinSign, numeral: settings.numeral)
    }

    private var phaseTitle: LocalizedStringKey {
        switch lunarAge.toPhase() {
        case .newMoon: "New moon"
        case .waxingCrescent: "Waxing crescent"
        case .firstQuarter: "First quarter"
        case .waxingGibbous: "Waxing gibbous"
        case .fullMoon: "Full moon"
        case .waningGibbous: "Waning gibbous"
        case .thirdQuarter: "Third quarter"
        case .waningCrescent: "Waning crescent"
        }
    }

    private var seasonLabel: String {
        let millis = Int(jdn.toDate().timeIntervalSince1970 * 1000)
        let season = Season.fromTimeInMillis(millis, coordinates: settings.coordinates)
        switch (season, settings.language) {
        case (.spring, .fa): return "بهار"
        case (.summer, .fa): return "تابستان"
        case (.autumn, .fa): return "پاییز"
        case (.winter, .fa): return "زمستان"
        case (.spring, .ar): return "الربيع"
        case (.summer, .ar): return "الصيف"
        case (.autumn, .ar): return "الخريف"
        case (.winter, .ar): return "الشتاء"
        case (.spring, .en): return "Spring"
        case (.summer, .en): return "Summer"
        case (.autumn, .en): return "Autumn"
        case (.winter, .en): return "Winter"
        }
    }

    private var animalYearLabel: String {
        let zodiac = ChineseZodiac.fromPersianCalendar(jdn.toPersianDate())
        let isPersian = settings.language.isPersianOrDari
        let emoji = zodiac.resolveEmoji(isPersian: isPersian)
        return "\(emoji) \(zodiac.localizedTitle(settings.language))"
    }

    private func zodiacLabel(_ zodiac: Zodiac) -> String {
        "\(zodiac.symbol) \(zodiac.localizedTitle(settings.language))"
    }

    private func scorpioLabel(_ state: MoonInScorpioState) -> String {
        switch state {
        case .borji: "Yes (tropical)"
        case .falaki: "Yes (constellation)"
        case let .start(clock): "From \(formatter.formatClock(clock))"
        case let .end(clock): "Until \(formatter.formatClock(clock))"
        }
    }

    private func clockText(_ time: AstroTime) -> String {
        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.hour, .minute], from: time.date)
        return formatter.formatClock(
            Clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0))
    }
}
