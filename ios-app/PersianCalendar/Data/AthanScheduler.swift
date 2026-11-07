import Foundation
import UserNotifications

/// Schedules local notifications for the prayer times the user has enabled.
///
/// Replaces the Android app's `AlarmManager` + foreground-service athan playback. iOS cannot wake
/// an app to play audio at a given moment, so this uses ordinary local notifications: the system
/// delivers them whether or not the app is running, and a custom sound can be attached.
///
/// iOS keeps at most 64 pending notifications per app, so a rolling window of days is scheduled
/// and topped up whenever the app becomes active.
@MainActor
@Observable
final class AthanScheduler {
    enum Authorization: Equatable {
        case notDetermined
        case authorized
        case denied
    }

    private(set) var authorization: Authorization = .notDetermined
    /// How many notifications are currently scheduled, for display in settings.
    private(set) var pendingCount = 0

    /// The prayer times that can raise an athan, matching the Android app's `PrayTime.athans`.
    static let athanTimes: [PrayTimeKind] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    /// iOS's hard ceiling is 64; leave headroom so nothing is silently dropped.
    private static let maximumPending = 60

    private let center = UNUserNotificationCenter.current()

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorization =
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: .authorized
            case .denied: .denied
            default: .notDetermined
            }
        pendingCount = await center.pendingNotificationRequests().count
    }

    @discardableResult
    func requestAuthorization() async -> Authorization {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorization = granted ? .authorized : .denied
        } catch {
            authorization = .denied
        }
        return authorization
    }

    /// Replace all scheduled athans with a fresh window starting today.
    ///
    /// Safe to call often; it is a no-op when no alarms are enabled or no location is set.
    func reschedule(settings: AppSettings) async {
        center.removeAllPendingNotificationRequests()

        let enabled = Self.athanTimes.filter { settings.athanAlarm.contains($0.rawValue) }
        guard !enabled.isEmpty, settings.coordinates != nil else {
            pendingCount = 0
            return
        }
        if authorization == .notDetermined { await requestAuthorization() }
        guard authorization == .authorized else {
            pendingCount = 0
            return
        }

        let now = Date()
        let today = Jdn.today()
        // Enough days to fill the budget, capped so a single-alarm setup doesn't schedule months
        // ahead and then drift out of date.
        let days = min(Self.maximumPending / enabled.count, 14)

        var scheduled = 0
        for dayOffset in 0..<days {
            let jdn = today + dayOffset
            guard let times = settings.prayTimes(for: jdn) else { continue }
            for kind in enabled {
                guard scheduled < Self.maximumPending else { break }
                let clock = Clock(kind.value(from: times))
                guard
                    let fireDate = Self.fireDate(
                        jdn: jdn, clock: clock, gapMinutes: settings.athanGapMinutes)
                else { continue }
                // Skip anything already in the past, which is most of today by evening.
                guard fireDate > now else { continue }
                await schedule(
                    kind: kind, at: fireDate, language: settings.language,
                    sound: settings.athanSound)
                scheduled += 1
            }
        }
        pendingCount = await center.pendingNotificationRequests().count
    }

    /// Cancel everything, e.g. when the user turns all alarms off.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        pendingCount = 0
    }

    // MARK: - Internals

    /// The wall-clock moment for a prayer time, moved earlier by the configured gap.
    private static func fireDate(jdn: Jdn, clock: Clock, gapMinutes: Double) -> Date? {
        guard !clock.value.isNaN else { return nil }
        let midnight = jdn.toDate()
        return midnight
            .addingTimeInterval(clock.value * 3600)
            .addingTimeInterval(-gapMinutes * 60)
    }

    private func schedule(
        kind: PrayTimeKind, at date: Date, language: AppLanguage, sound: AthanSound
    ) async {
        let content = UNMutableNotificationContent()
        content.title = kind.localizedTitle(language)
        content.body = Self.body(for: kind, language: language)
        content.sound = sound.notificationSound

        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "athan-\(kind.rawValue)-\(Int(date.timeIntervalSince1970))",
            content: content,
            trigger: trigger)
        try? await center.add(request)
    }

    private static func body(for kind: PrayTimeKind, language: AppLanguage) -> String {
        let name = kind.localizedTitle(language)
        switch language {
        case .fa: return "وقت \(name) فرا رسید"
        case .ar: return "حان وقت \(name)"
        case .en: return "It is time for \(name)"
        }
    }
}
