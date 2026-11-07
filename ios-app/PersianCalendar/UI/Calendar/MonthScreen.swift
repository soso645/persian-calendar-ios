import SwiftUI

/// A whole month as a scrollable list, one row per day with that day's events.
///
/// Complements the grid on the main screen: the grid shows shape, this shows content.
struct MonthScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceCalendarStore.self) private var deviceCalendar

    let today: Jdn
    @State private var monthStart: Jdn
    /// Show only days that have something on them.
    @State private var eventsOnly = false

    init(today: Jdn, startingAt: Jdn? = nil) {
        self.today = today
        _monthStart = State(initialValue: startingAt ?? today)
    }

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    private var calendar: CalendarKind { settings.mainCalendar }

    /// The first day of the month `monthStart` falls in.
    private var firstDay: Jdn {
        let date = monthStart.on(calendar)
        return Jdn(calendar, date.year, date.month, 1)
    }

    private var days: [Jdn] {
        let date = firstDay.on(calendar)
        let length = calendar.getMonthLength(year: date.year, month: date.month)
        return (0..<length).map { firstDay + $0 }
    }

    private func events(for jdn: Jdn) -> [CalendarEvent] {
        let device = settings.showDeviceCalendarEvents ? deviceCalendar.events(for: jdn) : []
        return settings.eventsRepository.events(for: jdn, deviceEvents: device)
    }

    var body: some View {
        List {
            ForEach(days, id: \.value) { jdn in
                let dayEvents = events(for: jdn)
                if !eventsOnly || !dayEvents.isEmpty {
                    DayRow(
                        jdn: jdn,
                        events: dayEvents,
                        isToday: jdn == today,
                        isWeekEnd: settings.weekEnds.contains(jdn.weekDay))
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $eventsOnly) {
                    Label("Events only", systemImage: "line.3.horizontal.decrease.circle")
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    monthStart = firstDay - 1
                } label: {
                    Label("Previous", systemImage: "chevron.backward")
                }
                Spacer()
                Text(title).font(.headline)
                Spacer()
                Button {
                    let date = firstDay.on(calendar)
                    let length = calendar.getMonthLength(year: date.year, month: date.month)
                    monthStart = firstDay + length
                } label: {
                    Label("Next", systemImage: "chevron.forward")
                }
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var title: String {
        let date = firstDay.on(calendar)
        return formatter.formatMonthYear(calendar, year: date.year, month: date.month)
    }
}

/// One day: its number and weekday, then whatever falls on it.
private struct DayRow: View {
    @Environment(AppSettings.self) private var settings

    let jdn: Jdn
    let events: [CalendarEvent]
    let isToday: Bool
    let isWeekEnd: Bool

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    private var isHoliday: Bool {
        isWeekEnd || events.contains(where: \.isHoliday)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(settings.numeral.format(jdn.on(settings.mainCalendar).dayOfMonth))
                    .font(.title3.weight(isToday ? .bold : .regular))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(isHoliday && settings.redHolidays ? .red : .primary)
                Text(formatter.weekDayInitial(jdn.weekDay))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40)
            .padding(.vertical, 2)
            .background {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if events.isEmpty {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(event.title)
                                .font(.subheadline)
                                .foregroundStyle(
                                    event.isHoliday && settings.redHolidays ? .red : .primary)
                            if let time = event.device?.time {
                                Text(time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
