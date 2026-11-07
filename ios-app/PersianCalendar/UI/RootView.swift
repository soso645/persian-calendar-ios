import SwiftUI

/// The app shell: a navigation stack over the calendar, with the other screens reachable from a
/// menu.
///
/// The Android app uses a wide navigation rail (a left drawer). On iPhone that idiom doesn't
/// belong, so the same destinations hang off a toolbar menu and push onto a `NavigationStack`.
struct RootView: View {
    @Environment(AppSettings.self) private var settings

    @State private var path = NavigationPath()

    enum Destination: Hashable, CaseIterable {
        case map
        case month
        case week
        case year
        case converter
        case compass
        case level
        case astronomy
        case settings
        case about

        #if DEBUG
        init?(name: String) {
            guard let match = Destination.allCases.first(where: { "\($0)" == name }) else {
                return nil
            }
            self = match
        }
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            CalendarScreen()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                path.append(Destination.month)
                            } label: {
                                Label("Month", systemImage: "list.bullet.rectangle")
                            }
                            Button {
                                path.append(Destination.week)
                            } label: {
                                Label("Week", systemImage: "calendar.day.timeline.left")
                            }
                            Button {
                                path.append(Destination.year)
                            } label: {
                                Label("Year", systemImage: "square.grid.3x3")
                            }
                            Divider()
                            Button {
                                path.append(Destination.converter)
                            } label: {
                                Label("Converter", systemImage: "arrow.left.arrow.right.circle")
                            }
                            Button {
                                path.append(Destination.compass)
                            } label: {
                                Label("Compass", systemImage: "location.north.circle")
                            }
                            Button {
                                path.append(Destination.level)
                            } label: {
                                Label("Level", systemImage: "level")
                            }
                            Button {
                                path.append(Destination.astronomy)
                            } label: {
                                Label("Astronomy", systemImage: "moon.stars")
                            }
                            Button {
                                path.append(Destination.map)
                            } label: {
                                Label("Map", systemImage: "globe")
                            }
                            Divider()
                            Button {
                                path.append(Destination.settings)
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                            Button {
                                path.append(Destination.about)
                            } label: {
                                Label("About", systemImage: "info.circle")
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .map: MapScreen()
                    case .month: MonthScreen(today: Jdn.today())
                    case .week: WeekScreen(today: Jdn.today())
                    case .year:
                        YearView(today: Jdn.today()) { _ in }
                    case .converter: ConverterScreen()
                    case .compass: CompassScreen()
                    case .level: LevelScreen()
                    case .astronomy: AstronomyScreen()
                    case .settings: SettingsScreen()
                    case .about: AboutScreen()
                    }
                }
        }
        .task {
            #if DEBUG
            // Lets a screenshot run open a screen directly: `-startScreen settings`.
            if let name = UserDefaults.standard.string(forKey: "startScreen"),
                let destination = Destination(name: name)
            {
                path.append(destination)
            }
            #endif
        }
        .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: settings.language.localeIdentifier))
        // Strings are resolved when a view body runs, so switching language has to rebuild the
        // tree rather than just invalidate it.
        .id(settings.language)
    }
}
