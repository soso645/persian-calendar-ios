import SwiftUI

/// One week at a time, with each day's events listed beneath it.
struct WeekScreen: View {
    @Environment(AppSettings.self) private var settings

    let today: Jdn
    @State private var anchor: Jdn

    init(today: Jdn, startingAt: Jdn? = nil) {
        self.today = today
        _anchor = State(initialValue: startingAt ?? today)
    }

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    /// The first day of the week `anchor` falls in, honouring the user's week start.
    private var weekStart: Jdn {
        anchor - (anchor.weekDay - settings.weekStart)
    }

    private var days: [Jdn] { (0..<7).map { weekStart + $0 } }

    var body: some View {
        List {
            ForEach(days, id: \.value) { jdn in
                Section {
                    let events = settings.eventsRepository.events(for: jdn)
                    if events.isEmpty {
                        Text("No events")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                            Text(event.title)
                                .font(.subheadline)
                                .foregroundStyle(
                                    event.isHoliday && settings.redHolidays ? .red : .primary)
                        }
                    }
                } header: {
                    HStack {
                        Text(formatter.weekDayName(jdn.weekDay))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(headerColor(jdn))
                        Spacer()
                        Text(
                            formatter.formatDate(
                                jdn.on(settings.mainCalendar), calendar: settings.mainCalendar))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if jdn == today {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle(weekTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { anchor = anchor - 7 } label: { Image(systemName: "chevron.backward") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { anchor = anchor + 7 } label: { Image(systemName: "chevron.forward") }
            }
        }
    }

    private func headerColor(_ jdn: Jdn) -> Color {
        guard settings.redHolidays else { return .primary }
        let isHoliday =
            settings.weekEnds.contains(jdn.weekDay)
            || settings.eventsRepository.events(for: jdn).contains(where: \.isHoliday)
        return isHoliday ? .red : .primary
    }

    private var weekTitle: String {
        let calendar = settings.mainCalendar
        let yearStart = Jdn(calendar, weekStart.on(calendar).year, 1, 1)
        let week = weekStart.getWeekOfYear(
            startOfYear: yearStart, weekStart: settings.weekStart)
        return "\(settings.numeral.format(week))"
    }
}
