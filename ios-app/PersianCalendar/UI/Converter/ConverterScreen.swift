import SwiftUI

/// Date conversion, day-distance, and the expression calculator.
///
/// Mirrors the Android Converter screen's modes.
struct ConverterScreen: View {
    @Environment(AppSettings.self) private var settings

    @State private var mode: Mode = .converter
    @State private var sourceCalendar: CalendarKind?
    @State private var jdn = Jdn.today()
    @State private var secondJdn = Jdn.today()
    @State private var calculatorText = ""

    enum Mode: String, CaseIterable, Identifiable {
        case converter, distance, calculator
        var id: String { rawValue }
        /// See the note on `DayDetailsView.Tab.title` — must be a `LocalizedStringKey`.
        var title: LocalizedStringKey {
            switch self {
            case .converter: "Convert"
            case .distance: "Distance"
            case .calculator: "Calculator"
            }
        }
    }

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    private var activeCalendar: CalendarKind { sourceCalendar ?? settings.mainCalendar }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            switch mode {
            case .converter: converterSection
            case .distance: distanceSection
            case .calculator: calculatorSection
            }
        }
        .navigationTitle("Converter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calculatorText = settings.calculatorInput }
    }

    // MARK: - Convert

    @ViewBuilder private var converterSection: some View {
        Section("Date") {
            CalendarDatePicker(calendar: activeCalendar, jdn: $jdn)
            Picker("Input calendar", selection: Binding(
                get: { activeCalendar }, set: { sourceCalendar = $0 })
            ) {
                ForEach(CalendarKind.allCases, id: \.self) {
                    Text($0.localizedTitle(settings.language)).tag($0)
                }
            }
        }

        Section("Equivalents") {
            ForEach(CalendarKind.allCases, id: \.self) { calendar in
                LabeledContent(calendar.localizedTitle(settings.language)) {
                    Text(formatter.formatDate(jdn.on(calendar), calendar: calendar))
                        .textSelection(.enabled)
                }
            }
            LabeledContent("Julian day") {
                Text(settings.numeral.format(jdn.value)).textSelection(.enabled)
            }
            LabeledContent("Week day") {
                Text(formatter.weekDayName(jdn.weekDay))
            }
        }

        Section("QR code") {
            // The QR encodes the converted date so it can be scanned into another device.
            QrCodeView(text: qrPayload)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private var qrPayload: String {
        let civil = jdn.toCivilDate()
        return String(format: "%04d-%02d-%02d", civil.year, civil.month, civil.dayOfMonth)
    }

    // MARK: - Distance

    @ViewBuilder private var distanceSection: some View {
        Section("From") { CalendarDatePicker(calendar: activeCalendar, jdn: $jdn) }
        Section("To") { CalendarDatePicker(calendar: activeCalendar, jdn: $secondJdn) }
        Section("Result") {
            let days = secondJdn - jdn
            LabeledContent("Days") {
                Text(settings.numeral.format(abs(days)))
            }
            let lower = min(jdn, secondJdn)
            let upper = max(jdn, secondJdn)
            let parts = calculateDatePartsDifference(
                from: lower.on(activeCalendar), to: upper.on(activeCalendar),
                calendar: activeCalendar)
            LabeledContent("Breakdown") {
                Text(
                    "\(settings.numeral.format(parts.years))y "
                        + "\(settings.numeral.format(parts.months))m "
                        + "\(settings.numeral.format(parts.days))d")
            }
            LabeledContent("Work days") {
                Text(
                    settings.numeral.format(
                        settings.eventsRepository.calculateWorkDays(
                            from: lower, to: upper, weekEnds: settings.weekEnds)))
            }
        }
    }

    // MARK: - Calculator

    @ViewBuilder private var calculatorSection: some View {
        Section("Input") {
            TextField("e.g. 1d 2h + 30m", text: $calculatorText, axis: .vertical)
                .lineLimit(3...8)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))
                .onChange(of: calculatorText) { _, newValue in
                    settings.calculatorInput = newValue
                }
        }
        Section("Result") {
            switch calculatorResult {
            case let .success(text):
                Text(text.isEmpty ? "—" : text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            case let .failure(error):
                Text(error.localizedDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var calculatorResult: Result<String, any Error> {
        guard !calculatorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .success("")
        }
        return Result { try Calculator.eval(calculatorText) }
    }
}

/// A three-wheel date picker in an arbitrary calendar system.
struct CalendarDatePicker: View {
    @Environment(AppSettings.self) private var settings

    let calendar: CalendarKind
    @Binding var jdn: Jdn

    var body: some View {
        let date = jdn.on(calendar)
        let months = CalendarNames.months(for: calendar, language: settings.language)
        let monthLength = calendar.getMonthLength(year: date.year, month: date.month)

        HStack(spacing: 0) {
            Picker("Year", selection: yearBinding(date.year)) {
                ForEach((date.year - 100)...(date.year + 100), id: \.self) {
                    Text(settings.numeral.format($0)).tag($0)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Month", selection: monthBinding(date.month)) {
                ForEach(1...12, id: \.self) { Text(months[$0 - 1]).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Day", selection: dayBinding(date.dayOfMonth)) {
                ForEach(1...max(monthLength, 1), id: \.self) {
                    Text(settings.numeral.format($0)).tag($0)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 140)
    }

    private func yearBinding(_ current: Int) -> Binding<Int> {
        Binding(get: { current }, set: { set(year: $0) })
    }
    private func monthBinding(_ current: Int) -> Binding<Int> {
        Binding(get: { current }, set: { set(month: $0) })
    }
    private func dayBinding(_ current: Int) -> Binding<Int> {
        Binding(get: { current }, set: { set(day: $0) })
    }

    /// Rebuild the date, clamping the day so e.g. the 31st doesn't fall off a 29-day month.
    private func set(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        let date = jdn.on(calendar)
        let newYear = year ?? date.year
        let newMonth = month ?? date.month
        let length = calendar.getMonthLength(year: newYear, month: newMonth)
        let newDay = min(day ?? date.dayOfMonth, length)
        jdn = Jdn(calendar, newYear, newMonth, newDay)
    }
}

/// Renders a QR matrix as a scalable grid of squares.
struct QrCodeView: View {
    let text: String

    var body: some View {
        let matrix = qr(text)
        Canvas { context, size in
            guard !matrix.isEmpty else { return }
            let count = matrix.count
            let cell = min(size.width, size.height) / Double(count)
            let originX = (size.width - cell * Double(count)) / 2
            let originY = (size.height - cell * Double(count)) / 2
            for (rowIndex, row) in matrix.enumerated() {
                for (columnIndex, isDark) in row.enumerated() where isDark {
                    let rect = CGRect(
                        x: originX + Double(columnIndex) * cell,
                        y: originY + Double(rowIndex) * cell,
                        width: cell, height: cell)
                    context.fill(Path(rect), with: .color(.primary))
                }
            }
        }
        .frame(width: 180, height: 180)
        .accessibilityLabel("QR code for \(text)")
    }
}
