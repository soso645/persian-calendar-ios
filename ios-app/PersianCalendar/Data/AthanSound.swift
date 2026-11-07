import AVFoundation
import Foundation
import UserNotifications

/// The athan recordings bundled with the app.
///
/// Ported from the Android app's `res/raw` audio, transcoded to CAF because iOS notification
/// sounds must be Linear PCM, IMA4, µLaw or aLaw in an aiff/wav/caf container, and no longer than
/// 30 seconds. All four originals came in under that.
enum AthanSound: String, CaseIterable, Identifiable, Sendable {
    /// The system's default notification sound rather than a recording.
    case standard
    case abdulbasit
    case entezar
    case moazzenzadeh
    case special

    var id: String { rawValue }

    /// Bundle filename, or nil for the system default.
    var fileName: String? {
        self == .standard ? nil : "\(rawValue).caf"
    }

    var notificationSound: UNNotificationSound {
        guard let fileName else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.standard, .fa): "پیش‌فرض"
        case (.standard, .ar): "الافتراضي"
        case (.standard, .en): "Default"
        case (.abdulbasit, .fa): "عبدالباسط"
        case (.abdulbasit, .ar): "عبد الباسط"
        case (.abdulbasit, .en): "Abdul Basit"
        case (.entezar, .fa): "انتظار"
        case (.entezar, .ar): "انتظار"
        case (.entezar, .en): "Entezar"
        case (.moazzenzadeh, .fa): "مؤذن‌زاده اردبیلی"
        case (.moazzenzadeh, .ar): "مؤذن زاده أردبيلي"
        case (.moazzenzadeh, .en): "Moazzenzadeh"
        case (.special, .fa): "ویژه"
        case (.special, .ar): "خاص"
        case (.special, .en): "Special"
        }
    }
}

/// Plays an athan recording so the user can hear it before choosing.
@MainActor
@Observable
final class AthanPreviewPlayer {
    private(set) var playing: AthanSound?
    private var player: AVAudioPlayer?

    func play(_ sound: AthanSound) {
        stop()
        guard let fileName = sound.fileName else { return }
        let name = (fileName as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        do {
            // Honour the ringer switch: a preview the user can't hear would be confusing, but so
            // would one that plays while the phone is silenced.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            playing = sound
        } catch {
            playing = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playing = nil
    }
}
