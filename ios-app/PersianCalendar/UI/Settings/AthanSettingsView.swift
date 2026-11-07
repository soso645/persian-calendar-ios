import SwiftUI

/// Choose which prayer times raise a notification, and how far ahead of time.
struct AthanSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AthanScheduler.self) private var scheduler

    @State private var preview = AthanPreviewPlayer()

    var body: some View {
        @Bindable var settings = settings

        Form {
            if settings.coordinates == nil {
                Section {
                    Text("Set a location in Settings to enable athan notifications.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if scheduler.authorization == .denied {
                Section {
                    Label(
                        "Notifications are turned off for this app in iOS Settings.",
                        systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Athan") {
                ForEach(AthanScheduler.athanTimes) { kind in
                    Toggle(
                        kind.localizedTitle(settings.language),
                        isOn: Binding(
                            get: { settings.athanAlarm.contains(kind.rawValue) },
                            set: { isOn in
                                var alarms = settings.athanAlarm
                                if isOn {
                                    alarms.insert(kind.rawValue)
                                } else {
                                    alarms.remove(kind.rawValue)
                                }
                                settings.athanAlarm = alarms
                            }))
                }
                .disabled(settings.coordinates == nil)
            }

            Section("Sound") {
                ForEach(AthanSound.allCases) { sound in
                    Button {
                        settings.athanSound = sound
                        preview.play(sound)
                    } label: {
                        HStack {
                            Text(sound.localizedTitle(settings.language))
                                .foregroundStyle(.primary)
                            Spacer()
                            if preview.playing == sound {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.secondary)
                            }
                            if settings.athanSound == sound {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            Section {
                Stepper(value: $settings.athanGapMinutes, in: 0...30, step: 1) {
                    LabeledContent("Notify early") {
                        Text(
                            settings.numeral.format(Int(settings.athanGapMinutes)) + " min")
                    }
                }
                .disabled(settings.athanAlarm.isEmpty)
            } footer: {
                Text("Notifications arrive this many minutes before the prayer time.")
            }

            Section {
                LabeledContent("Scheduled") {
                    Text(settings.numeral.format(scheduler.pendingCount))
                }
            } footer: {
                Text(
                    "iOS allows a limited number of pending notifications, so a rolling window of "
                        + "days is scheduled and refreshed each time the app is opened.")
            }
        }
        .navigationTitle("Athan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await scheduler.refreshAuthorization() }
        .onDisappear { preview.stop() }
        // Any change to the enabled set, the gap or the location invalidates the schedule.
        .task(id: ScheduleInputs(settings)) {
            await scheduler.reschedule(settings: settings)
        }
    }

    /// The inputs that make a rescheduling necessary.
    private struct ScheduleInputs: Equatable {
        let alarms: Set<String>
        let gap: Double
        let latitude: Double?
        let longitude: Double?
        let method: CalculationMethod
        let sound: AthanSound

        @MainActor
        init(_ settings: AppSettings) {
            alarms = settings.athanAlarm
            gap = settings.athanGapMinutes
            latitude = settings.coordinates?.latitude
            longitude = settings.coordinates?.longitude
            method = settings.prayTimeMethod
            sound = settings.athanSound
        }
    }
}
