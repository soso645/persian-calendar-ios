import SwiftUI

/// The composition root.
///
/// Creates the three long-lived observable stores the interface reads from the environment — the
/// settings, the EventKit-backed device calendar, and the athan scheduler — and keeps the athan
/// window topped up. iOS only allows a limited number of pending notifications, so the scheduler
/// is refreshed at launch and on every return to the foreground; no background task does it.
@main
struct PersianCalendarApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings = AppSettings.shared
    @State private var deviceCalendar = DeviceCalendarStore()
    @State private var athanScheduler = AthanScheduler()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(deviceCalendar)
                .environment(athanScheduler)
                .task {
                    await athanScheduler.refreshAuthorization()
                    await athanScheduler.reschedule(settings: settings)
                }
                .onChange(of: scenePhase) { _, phase in
                    // Only a rolling window of days is scheduled, so top it up on each return
                    // to the app rather than relying on a background task.
                    guard phase == .active else { return }
                    Task { await athanScheduler.reschedule(settings: settings) }
                }
        }
    }
}
