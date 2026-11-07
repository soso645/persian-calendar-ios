import SwiftUI

/// Jump to an arbitrary date, entered in whichever calendar the user picks.
struct GoToDateSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedJdn: Jdn
    let onSelect: (Jdn) -> Void

    @State private var calendar: CalendarKind?
    @State private var year = 0
    @State private var month = 1
    @State private var day = 1

    private var activeCalendar: CalendarKind { calendar ?? settings.mainCalendar }

    private var monthNames: [String] {
        CalendarNames.months(for: activeCalendar, language: settings.language)
    }

    private var monthLength: Int {
        activeCalendar.getMonthLength(year: year, month: month)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Calendar", selection: Binding(
                    get: { activeCalendar },
                    set: { newValue in
                        // Re-express the current date in the newly chosen calendar.
                        let jdn = Jdn(activeCalendar, year, month, day)
                        calendar = newValue
                        let date = jdn.on(newValue)
                        year = date.year
                        month = date.month
                        day = date.dayOfMonth
                    })
                ) {
                    ForEach(CalendarKind.allCases, id: \.self) { kind in
                        Text(kind.localizedTitle(settings.language)).tag(kind)
                    }
                }

                Picker("Year", selection: $year) {
                    ForEach((year - 100)...(year + 100), id: \.self) { value in
                        Text(settings.numeral.format(value)).tag(value)
                    }
                }

                Picker("Month", selection: $month) {
                    ForEach(1...12, id: \.self) { value in
                        Text(monthNames[value - 1]).tag(value)
                    }
                }

                Picker("Day", selection: $day) {
                    ForEach(1...max(monthLength, 1), id: \.self) { value in
                        Text(settings.numeral.format(value)).tag(value)
                    }
                }
            }
            .navigationTitle("Go to date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        let clamped = min(day, monthLength)
                        let jdn = Jdn(activeCalendar, year, month, clamped)
                        selectedJdn = jdn
                        onSelect(jdn)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let date = selectedJdn.on(activeCalendar)
            year = date.year
            month = date.month
            day = date.dayOfMonth
        }
        .onChange(of: month) { _, _ in
            if day > monthLength { day = monthLength }
        }
    }
}
