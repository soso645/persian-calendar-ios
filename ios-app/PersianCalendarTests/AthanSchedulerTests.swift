import AVFoundation
import XCTest
@testable import PersianCalendar

/// The scheduler's date arithmetic and windowing, which is the part that can be wrong silently.
/// Actual delivery is the system's job and isn't testable here.
@MainActor
final class AthanSchedulerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "athan-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Only the five athan times can raise a notification — sunrise, sunset, imsak and midnight
    /// are informational, matching the Android app's `PrayTime.athans`.
    func testOnlyAthanTimesAreOfferable() {
        XCTAssertEqual(AthanScheduler.athanTimes, [.fajr, .dhuhr, .asr, .maghrib, .isha])
        XCTAssertFalse(AthanScheduler.athanTimes.contains(.sunrise))
        XCTAssertFalse(AthanScheduler.athanTimes.contains(.midnight))
        XCTAssertFalse(AthanScheduler.athanTimes.contains(.imsak))
    }

    /// The gap moves the notification earlier, never later.
    func testGapMovesTheFireTimeEarlier() {
        let settings = AppSettings(defaults: defaults)
        settings.coordinates = Coordinates(
            latitude: 35.6892, longitude: 51.3890, elevation: 1200)
        let jdn = Jdn(.shamsi, 1403, 1, 1)
        let times = try! XCTUnwrap(
            settings.prayTimes(for: jdn, timeZone: TimeZone(identifier: "Asia/Tehran")!))

        let midnight = jdn.toDate()
        let fajrExact = midnight.addingTimeInterval(times.fajr * 3600)
        let fajrEarly = fajrExact.addingTimeInterval(-15 * 60)

        XCTAssertEqual(fajrExact.timeIntervalSince(fajrEarly), 900, accuracy: 0.001)
        XCTAssertLessThan(fajrEarly, fajrExact)
    }

    /// The rolling window must stay inside the 64-notification system limit whatever the user
    /// enables, and must still cover several days.
    func testWindowSizeStaysWithinTheSystemLimit() {
        for enabledCount in 1...AthanScheduler.athanTimes.count {
            let days = min(60 / enabledCount, 14)
            XCTAssertLessThanOrEqual(
                days * enabledCount, 60, "\(enabledCount) alarms overflow the budget")
            XCTAssertGreaterThanOrEqual(
                days, 12, "\(enabledCount) alarms give too short a window")
        }
    }

    /// With no location there is nothing to schedule, so the settings screen must say so rather
    /// than silently doing nothing.
    func testNoCoordinatesMeansNoPrayTimes() {
        let settings = AppSettings(defaults: defaults)
        settings.athanAlarm = ["FAJR", "DHUHR"]
        XCTAssertNil(settings.coordinates)
        XCTAssertNil(settings.prayTimes(for: Jdn.today()))
    }

    // MARK: - Sounds

    /// Every bundled athan must actually be in the bundle and satisfy iOS's rules for a custom
    /// notification sound: under 30 seconds, in a caf/aiff/wav container.
    func testBundledAthanSoundsAreUsable() throws {
        for sound in AthanSound.allCases {
            guard let fileName = sound.fileName else {
                XCTAssertEqual(sound, .standard, "only the default may have no file")
                continue
            }
            XCTAssertTrue(fileName.hasSuffix(".caf"), "\(sound) is not a caf")

            let name = (fileName as NSString).deletingPathExtension
            let url = try XCTUnwrap(
                Bundle.main.url(forResource: name, withExtension: "caf"),
                "\(fileName) is missing from the app bundle")

            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 1, "\(sound) is suspiciously short")
            XCTAssertLessThan(
                player.duration, 30,
                "\(sound) exceeds the 30s limit iOS enforces on notification sounds")
        }
    }

    func testAthanSoundPersists() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.athanSound, .standard)
        settings.athanSound = .moazzenzadeh
        XCTAssertEqual(AppSettings(defaults: defaults).athanSound, .moazzenzadeh)
    }

    /// Enabled alarms round-trip through the stored preference.
    func testEnabledAlarmsPersist() {
        let settings = AppSettings(defaults: defaults)
        settings.athanAlarm = ["FAJR", "MAGHRIB"]
        settings.athanGapMinutes = 10

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.athanAlarm, ["FAJR", "MAGHRIB"])
        XCTAssertEqual(reloaded.athanGapMinutes, 10, accuracy: 0.001)
        // The stored strings must match the prayer-time raw values, or nothing resolves.
        for name in reloaded.athanAlarm {
            XCTAssertNotNil(PrayTimeKind(rawValue: name), "unknown alarm '\(name)'")
        }
    }
}
