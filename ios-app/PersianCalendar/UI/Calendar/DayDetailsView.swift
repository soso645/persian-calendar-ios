import SwiftUI

/// Details for the selected day: the date in every enabled calendar, its events, and prayer times.
///
/// Stands in for the Android original's three detail tabs.
struct DayDetailsView: View {
    @Environment(AppSettings.self) private var settings

    let jdn: Jdn
    let today: Jdn

    @State private var tab: Tab = .events

    enum Tab: String, CaseIterable, Identifiable {
        case events, times
        var id: String { rawValue }

        /// A `LocalizedStringKey`, not a `String`: `Text` only localizes the former, so a plain
        /// String here would silently ship untranslated.
        var title: LocalizedStringKey {
            switch self {
            case .events: "Events"
            case .times: "Times"
            }
        }
    }

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 6)

            switch tab {
            case .events: EventsList(jdn: jdn)
            case .times: TimesList(jdn: jdn)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(formatter.formatFullDate(jdn, calendar: settings.mainCalendar))
                .font(.headline)

            ForEach(settings.otherCalendars.filter { $0 != settings.mainCalendar }, id: \.self) { calendar in
                Text(
                    "\(calendar.localizedTitle(settings.language))\(formatter.spacedColon)"
                        + formatter.formatDate(jdn.on(calendar), calendar: calendar)
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if jdn != today {
                Text(relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private var relativeDescription: String {
        let days = jdn - today
        let magnitude = settings.numeral.format(abs(days))
        switch settings.language {
        case .fa: return days > 0 ? "\(magnitude) روز بعد" : "\(magnitude) روز قبل"
        case .ar: return days > 0 ? "بعد \(magnitude) يوم" : "قبل \(magnitude) يوم"
        case .en: return days > 0 ? "in \(magnitude) days" : "\(magnitude) days ago"
        }
    }
}

/// The day's events, holidays first.
private struct EventsList: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceCalendarStore.self) private var deviceCalendar

    let jdn: Jdn

    private var events: [CalendarEvent] {
        let device = settings.showDeviceCalendarEvents ? deviceCalendar.events(for: jdn) : []
        return settings.eventsRepository.events(for: jdn, deviceEvents: device)
    }

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView(
                "No events",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Nothing recorded for this day."))
        } else {
            List(Array(events.enumerated()), id: \.offset) { _, event in
                HStack(alignment: .top, spacing: 8) {
                    Image(
                        systemName: event.isDeviceEvent
                            ? "person.crop.circle" : (event.isHoliday ? "star.fill" : "circle.fill")
                    )
                    .font(.system(size: event.isDeviceEvent ? 12 : (event.isHoliday ? 10 : 6)))
                        .foregroundStyle(
                            event.isHoliday && settings.redHolidays ? Color.red : Color.accentColor)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline)
                            .foregroundStyle(
                                event.isHoliday && settings.redHolidays ? Color.red : Color.primary)
                        if let time = event.device?.time {
                            Text(time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let alias = event.metadata.alias {
                            Text(alias)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.plain)
        }
    }
}

/// Prayer times for the day, or a prompt to set a location.
private struct TimesList: View {
    @Environment(AppSettings.self) private var settings

    let jdn: Jdn

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    var body: some View {
        if let times = settings.prayTimes(for: jdn) {
            List {
                ForEach(PrayTimeKind.allCases) { kind in
                    HStack {
                        Image(systemName: kind.systemImage)
                            .foregroundStyle(kind.tint)
                            .frame(width: 24)
                        Text(kind.localizedTitle(settings.language))
                        Spacer()
                        Text(formatter.formatClock(Clock(kind.value(from: times))))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
        } else {
            ContentUnavailableView(
                "No location set",
                systemImage: "location.slash",
                description: Text("Set a location in Settings to see prayer times."))
        }
    }
}
