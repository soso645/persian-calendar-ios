import SwiftUI

/// Twelve miniature month grids for a whole year; tapping one jumps the main calendar to it.
struct YearView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let today: Jdn
    /// Called with the first day of the tapped month.
    let onSelectMonth: (Jdn) -> Void

    @State private var year: Int

    init(today: Jdn, initialYear: Int? = nil, onSelectMonth: @escaping (Jdn) -> Void) {
        self.today = today
        self.onSelectMonth = onSelectMonth
        _year = State(initialValue: initialYear ?? 0)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(1...12, id: \.self) { month in
                    MiniMonth(year: resolvedYear, month: month, today: today)
                        .onTapGesture {
                            onSelectMonth(Jdn(settings.mainCalendar, resolvedYear, month, 1))
                            dismiss()
                        }
                }
            }
            .padding()
        }
        .navigationTitle(settings.numeral.format(resolvedYear))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            // A bottom stepper rather than toolbar chevrons: in RTL those sit next to the
            // navigation back button and read as three near-identical arrows.
            HStack {
                Button { year = resolvedYear - 1 } label: {
                    Label("Previous", systemImage: "chevron.backward")
                }
                Spacer()
                Text(settings.numeral.format(resolvedYear))
                    .font(.headline.monospacedDigit())
                Spacer()
                Button { year = resolvedYear + 1 } label: {
                    Label("Next", systemImage: "chevron.forward")
                }
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .onAppear {
            if year == 0 { year = today.on(settings.mainCalendar).year }
        }
    }

    private var resolvedYear: Int {
        year == 0 ? today.on(settings.mainCalendar).year : year
    }
}

/// A compact month: name, weekday initials and day numbers, with holidays coloured.
private struct MiniMonth: View {
    @Environment(AppSettings.self) private var settings

    let year: Int
    let month: Int
    let today: Jdn

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    var body: some View {
        let calendar = settings.mainCalendar
        let start = Jdn(calendar, year, month, 1)
        let length = calendar.getMonthLength(year: year, month: month)
        let leading = start.weekDay - settings.weekStart

        VStack(spacing: 4) {
            Text(formatter.monthName(calendar, month))
                .font(.caption.weight(.semibold))

            let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(0..<7, id: \.self) { index in
                    Text(formatter.weekDayInitial(settings.weekStart + index))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 1) {
                // Positional ids: blank padding cells would otherwise all share one id.
                ForEach(0..<(leading + length), id: \.self) { position in
                    if position < leading {
                        Color.clear.frame(height: 14)
                    } else {
                        let offset = position - leading
                        let jdn = start + offset
                        Text(settings.numeral.format(offset + 1))
                            .font(.system(size: 9))
                            .frame(height: 14)
                            .foregroundStyle(color(for: jdn))
                            .background {
                                if jdn == today {
                                    Circle().fill(Color.accentColor.opacity(0.25))
                                }
                            }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
        .contentShape(Rectangle())
    }

    private func color(for jdn: Jdn) -> Color {
        guard settings.redHolidays else { return .primary }
        let isHoliday =
            settings.weekEnds.contains(jdn.weekDay)
            || settings.eventsRepository.events(for: jdn).contains(where: \.isHoliday)
        return isHoliday ? .red : .primary
    }
}
