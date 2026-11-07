import SwiftUI

/// App settings, grouped the way the Android original's three tabs are.
struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Interface") {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                Toggle("Local digits", isOn: $settings.localNumeral)
                Toggle("Bold font", isOn: $settings.boldFont)
                Toggle("Red holidays", isOn: $settings.redHolidays)
                Toggle("Numeric dates", isOn: $settings.numericalDatePreferred)
                Toggle("Week of year numbers", isOn: $settings.showWeekOfYearNumber)
            }

            Section("Calendar") {
                Picker("Main calendar", selection: $settings.mainCalendar) {
                    ForEach(CalendarKind.allCases, id: \.self) { kind in
                        Text(kind.localizedTitle(settings.language)).tag(kind)
                    }
                }
                Toggle("Secondary date in grid", isOn: $settings.secondaryCalendarInTable)
                Picker("Week starts on", selection: $settings.weekStart) {
                    ForEach(WeekDay.allCases, id: \.self) { day in
                        Text(CalendarNames.weekDays(settings.language)[day.rawValue]).tag(day)
                    }
                }
                // The label and value must stay separate: interpolating into the string would
                // make it a format key that no localization contains.
                Stepper(value: $settings.hijriOffset, in: -3...3) {
                    LabeledContent("Hijri offset") {
                        Text(settings.numeral.format(settings.hijriOffset))
                    }
                }
                NavigationLink("Holidays and events") { HolidayTypesView() }
                NavigationLink("Shift work") { ShiftWorkView() }
            }

            Section("Location") {
                NavigationLink {
                    LocationPickerView()
                } label: {
                    LabeledContent("City") {
                        Text(currentLocationName)
                    }
                }
                Toggle("Iran time", isOn: $settings.iranTime)
            }

            Section("Prayer times") {
                Picker("Method", selection: $settings.prayTimeMethod) {
                    ForEach(CalculationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                Picker("Asr", selection: $settings.asrHanafiJuristic) {
                    Text("Standard").tag(false)
                    Text("Hanafi").tag(true)
                }
                Picker("High latitudes", selection: $settings.highLatitudesMethod) {
                    ForEach(HighLatitudesMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                NavigationLink("Athan") { AthanSettingsView() }
            }

            Section("Compass") {
                Toggle("Show qibla", isOn: $settings.showQiblaInCompass)
                Toggle("Use true north", isOn: $settings.trueNorthInCompass)
            }

            Section("Device calendar") {
                Toggle("Show device events", isOn: $settings.showDeviceCalendarEvents)
            }

            Section("Astronomy") {
                Toggle("Astronomical features", isOn: $settings.astronomicalFeatures)
                Toggle("Moon in Scorpio", isOn: $settings.showMoonInScorpio)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentLocationName: String {
        if let name = settings.geocodedCityName, !name.isEmpty { return name }
        if let city = CitiesData.shared.first(where: { $0.key == settings.selectedLocation }),
            city.key != "CUSTOM"
        {
            return city.localizedName(for: settings.language)
        }
        if let coordinates = settings.coordinates {
            return String(
                format: "%.3f, %.3f", coordinates.latitude, coordinates.longitude)
        }
        return "None"
    }
}

/// Which sets of holidays and events to show.
private struct HolidayTypesView: View {
    @Environment(AppSettings.self) private var settings

    private static let options: [(key: String, title: String)] = [
        (EventsRepository.iranHolidaysKey, "Iran holidays"),
        (EventsRepository.iranOthersKey, "Iran other events"),
        (EventsRepository.iranAncientKey, "Ancient Iran"),
        (EventsRepository.afghanistanHolidaysKey, "Afghanistan holidays"),
        (EventsRepository.afghanistanOthersKey, "Afghanistan other events"),
        (EventsRepository.nepalHolidaysKey, "Nepal holidays"),
        (EventsRepository.nepalOthersKey, "Nepal other events"),
        (EventsRepository.internationalKey, "International"),
    ]

    var body: some View {
        List {
            ForEach(Self.options, id: \.key) { option in
                Toggle(
                    option.title,
                    isOn: Binding(
                        get: { settings.holidayTypes.contains(option.key) },
                        set: { isOn in
                            var types = settings.holidayTypes
                            if isOn { types.insert(option.key) } else { types.remove(option.key) }
                            settings.holidayTypes = types
                        }))
            }
        }
        .navigationTitle("Holidays and events")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Pick a city from the bundled list, or use the device's location.
private struct LocationPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var grouped: [(country: String, cities: [CityItem])] {
        let matching = CitiesData.shared.filter { city in
            guard city.key != "CUSTOM" else { return false }
            guard !query.isEmpty else { return true }
            let needle = query.lowercased()
            return city.en.lowercased().contains(needle)
                || city.fa.contains(query)
                || city.ar.contains(query)
        }
        return Dictionary(grouping: matching, by: \.countryCode)
            .map { code, cities in
                (
                    country: cities.first?.localizedCountry(for: settings.language) ?? code,
                    cities: cities.sorted {
                        $0.localizedName(for: settings.language)
                            < $1.localizedName(for: settings.language)
                    }
                )
            }
            .sorted { $0.country < $1.country }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.country) { group in
                Section(group.country) {
                    ForEach(group.cities) { city in
                        Button {
                            settings.selectedLocation = city.key
                            settings.geocodedCityName = city.localizedName(for: settings.language)
                            settings.coordinates = city.coordinates
                            dismiss()
                        } label: {
                            HStack {
                                Text(city.localizedName(for: settings.language))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if settings.selectedLocation == city.key {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query)
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
    }
}
