import SwiftUI

/// Edit the repeating shift-work rota: a start date and a list of (shift type, length) entries.
struct ShiftWorkView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsStartPicker = false

    private var formatter: DateFormatter_ {
        DateFormatter_(language: settings.language, numeral: settings.numeral)
    }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Button {
                    showsStartPicker = true
                } label: {
                    LabeledContent("Starting day") {
                        Text(startDayText).foregroundStyle(.secondary)
                    }
                }
                Toggle("Repeats", isOn: $settings.shiftWorkRecurs)
            } footer: {
                Text(
                    "The rota begins on the starting day and repeats through the entries below.")
            }

            Section("Shifts") {
                ForEach(Array(settings.shiftWorkRecords.enumerated()), id: \.offset) { index, _ in
                    ShiftRow(
                        record: Binding(
                            get: { settings.shiftWorkRecords[index] },
                            set: { settings.shiftWorkRecords[index] = $0 }))
                }
                .onDelete { offsets in
                    settings.shiftWorkRecords.remove(atOffsets: offsets)
                }
                .onMove { source, destination in
                    settings.shiftWorkRecords.move(fromOffsets: source, toOffset: destination)
                }

                Button {
                    settings.shiftWorkRecords.append(ShiftWorkRecord(type: "", length: 1))
                } label: {
                    Label("Add shift", systemImage: "plus")
                }
            }

            if !settings.shiftWorkRecords.isEmpty, settings.shiftWorkStartingJdn != nil {
                Section("Preview") {
                    let start = settings.shiftWorkStartingJdn ?? Jdn.today()
                    let rota = settings.shiftWork
                    ForEach(0..<min(14, max(totalLength, 1)), id: \.self) { offset in
                        let jdn = start + offset
                        LabeledContent(
                            formatter.formatDate(
                                jdn.on(settings.mainCalendar), calendar: settings.mainCalendar)
                        ) {
                            Text(rota.workTitle(for: jdn) ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Clear rota", role: .destructive) {
                    settings.shiftWorkRecords = []
                    settings.shiftWorkStartingJdn = nil
                }
                .disabled(settings.shiftWorkRecords.isEmpty && settings.shiftWorkStartingJdn == nil)
            }
        }
        .navigationTitle("Shift work")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showsStartPicker) {
            NavigationStack {
                CalendarDatePicker(
                    calendar: settings.mainCalendar,
                    jdn: Binding(
                        get: { settings.shiftWorkStartingJdn ?? Jdn.today() },
                        set: { settings.shiftWorkStartingJdn = $0 }))
                    .padding()
                    .navigationTitle("Starting day")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsStartPicker = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private var totalLength: Int {
        settings.shiftWorkRecords.reduce(0) { $0 + $1.length }
    }

    private var startDayText: String {
        guard let jdn = settings.shiftWorkStartingJdn else { return "None" }
        return formatter.formatDate(
            jdn.on(settings.mainCalendar), calendar: settings.mainCalendar)
    }
}

/// One rota entry: a free-text shift name and how many days it runs for.
private struct ShiftRow: View {
    @Binding var record: ShiftWorkRecord

    var body: some View {
        HStack {
            TextField(
                "Shift name",
                text: Binding(
                    get: { record.type },
                    set: { record = ShiftWorkRecord(type: $0, length: record.length) }))
                .textInputAutocapitalization(.never)

            Stepper(
                value: Binding(
                    get: { record.length },
                    set: { record = ShiftWorkRecord(type: record.type, length: $0) }),
                in: 1...31
            ) {
                Text("\(record.length)d")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
        }
    }
}
