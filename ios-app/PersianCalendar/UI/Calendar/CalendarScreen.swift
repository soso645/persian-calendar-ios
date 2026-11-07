import SwiftUI

/// The app's main screen: a swipeable month grid over a detail pane for the selected day.
///
/// The Android original is a Compose `HorizontalPager` of month tables with a bottom sheet of
/// detail tabs. Here the pager is a paged `TabView` and the details sit below it, which is the
/// iOS-native reading of the same layout.
struct CalendarScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceCalendarStore.self) private var deviceCalendar

    @State private var today = Jdn.today()
    @State private var selectedJdn = Jdn.today()
    @State private var monthOffset = 0
    @State private var showsGoToDate = false

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthPager(
                today: today,
                monthOffset: $monthOffset,
                selectedJdn: $selectedJdn)
            .frame(height: 340)

            Divider()

            DayDetailsView(jdn: selectedJdn, today: today)
        }
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation {
                        monthOffset = 0
                        selectedJdn = today
                    }
                } label: {
                    Label("Today", systemImage: "smallcircle.filled.circle")
                }
                .disabled(monthOffset == 0 && selectedJdn == today)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsGoToDate = true
                } label: {
                    Label("Go to date", systemImage: "calendar")
                }
            }
        }
        .sheet(isPresented: $showsGoToDate) {
            GoToDateSheet(selectedJdn: $selectedJdn) { jdn in
                monthOffset = settings.mainCalendar.getMonthsDistance(from: today, to: jdn)
            }
        }
        .task(id: settings.showDeviceCalendarEvents) {
            guard settings.showDeviceCalendarEvents else { return }
            if deviceCalendar.access == .notDetermined {
                await deviceCalendar.requestAccess()
            }
            reloadDeviceEvents()
        }
        .onChange(of: monthOffset) { _, _ in reloadDeviceEvents() }
        .task {
            // Keep "today" honest across a midnight rollover while the app is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                let now = Jdn.today()
                if now != today { today = now }
            }
        }
    }

    /// Keep a couple of months of device events loaded around whatever is on screen.
    private func reloadDeviceEvents() {
        guard settings.showDeviceCalendarEvents, deviceCalendar.access == .granted else { return }
        let centre = settings.mainCalendar.getMonthStartFromMonthsDistance(
            baseJdn: today, monthsDistance: monthOffset)
        let start = Jdn(centre) - 40
        deviceCalendar.load(
            from: start, to: start + 120,
            formatter: DateFormatter_(language: settings.language, numeral: settings.numeral))
    }

    private var monthTitle: String {
        let start = settings.mainCalendar.getMonthStartFromMonthsDistance(
            baseJdn: today, monthsDistance: monthOffset)
        return formatter.formatMonthYear(
            settings.mainCalendar, year: start.year, month: start.month)
    }
}

/// A horizontally paged run of months.
private struct MonthPager: View {
    @Environment(AppSettings.self) private var settings

    let today: Jdn
    @Binding var monthOffset: Int
    @Binding var selectedJdn: Jdn

    /// How many months are reachable by swiping in each direction.
    private let range = 600

    var body: some View {
        TabView(selection: $monthOffset) {
            ForEach(-range...range, id: \.self) { offset in
                MonthView(
                    grid: MonthGrid.build(
                        offset: offset,
                        today: today,
                        settings: MonthGrid.Snapshot(settings)),
                    today: today,
                    selectedJdn: $selectedJdn)
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .accessibilityElement(children: .contain)
        // The pager lays out left-to-right regardless of script; month order should follow the
        // reading direction, so the whole pager is flipped for RTL languages.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// One month's grid of days.
private struct MonthView: View {
    @Environment(AppSettings.self) private var settings

    let grid: MonthGrid
    let today: Jdn
    @Binding var selectedJdn: Jdn

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                if !grid.weekNumbers.isEmpty {
                    Text("")
                        .frame(width: 22)
                }
                ForEach(Array(grid.weekDayInitials.enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            HStack(alignment: .top, spacing: 2) {
                if !grid.weekNumbers.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(Array(grid.weekNumbers.enumerated()), id: \.offset) { _, number in
                            Text(number)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 22)
                }

                LazyVGrid(columns: columns, spacing: 2) {
                    // Identified by grid position: the blank padding cells are all equal, so a
                    // value-based id would collide and drop cells.
                    ForEach(Array(grid.cells.enumerated()), id: \.offset) { _, cell in
                        DayCellView(
                            cell: cell,
                            isToday: cell.jdn == today,
                            isSelected: cell.jdn == selectedJdn)
                        .onTapGesture {
                            if let jdn = cell.jdn { selectedJdn = jdn }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .environment(\.layoutDirection, settings.language.isRTL ? .rightToLeft : .leftToRight)
    }
}

/// A single day in the grid.
private struct DayCellView: View {
    @Environment(AppSettings.self) private var settings

    let cell: DayCell
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 1) {
            if let dayOfMonth = cell.dayOfMonth {
                Text(settings.numeral.format(dayOfMonth))
                    // Scales with Dynamic Type, but capped: past .xxLarge the digits stop
                    // fitting seven to a row and the grid breaks up.
                    .font(.system(.body, design: .default,
                                  weight: settings.boldFont ? .semibold : .regular))
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(foreground)

                if let secondary = cell.secondaryLabel {
                    Text(secondary)
                        .font(.caption2)
                        .dynamicTypeSize(...DynamicTypeSize.medium)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 2) {
                    if cell.hasEvent {
                        Circle()
                            .fill(cell.isHoliday && settings.redHolidays ? Color.red : Color.accentColor)
                            .frame(width: 4, height: 4)
                    }
                    if cell.hasAppointment {
                        Circle().fill(Color.orange).frame(width: 4, height: 4)
                    }
                    if cell.isMoonInScorpio {
                        Text("♏").font(.system(size: 7))
                    }
                }
                .frame(height: 5)

                if let shift = cell.shiftWorkTitle {
                    Text(shift)
                        .font(.caption2)
                        .dynamicTypeSize(...DynamicTypeSize.small)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 46)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.18))
            }
            if isToday {
                RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cell.accessibilityLabel ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHidden(cell.jdn == nil)
    }

    private var foreground: Color {
        if cell.isHoliday && settings.redHolidays { return .red }
        return .primary
    }
}
