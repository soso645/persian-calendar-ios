import Combine
import CoreLocation
import CoreMotion
import Foundation

/// Device heading and attitude, backing the compass and level screens.
///
/// Replaces the Android `SensorManager` / `OrientationProvider` plumbing with CoreMotion and
/// CoreLocation. Heading needs CoreLocation because only it exposes magnetic and true north.
@MainActor
@Observable
final class MotionProvider: NSObject {
    /// Degrees clockwise from north; nil until the first reading arrives.
    private(set) var heading: Double?
    /// True when the reported heading is referenced to true north rather than magnetic north.
    private(set) var isTrueNorth = false
    /// Device tilt in degrees, for the level screen.
    private(set) var roll: Double = 0
    private(set) var pitch: Double = 0
    private(set) var isLevelAvailable = false
    private(set) var authorizationDenied = false

    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func startHeading(trueNorth: Bool) {
        isTrueNorth = trueNorth
        guard CLLocationManager.headingAvailable() else { return }
        // True north requires a location fix, magnetic north does not.
        if trueNorth {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.startUpdatingLocation()
        }
        locationManager.headingFilter = 0.5
        locationManager.startUpdatingHeading()
    }

    func stopHeading() {
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }

    func startLevel() {
        guard motionManager.isDeviceMotionAvailable else {
            isLevelAvailable = false
            return
        }
        isLevelAvailable = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 30
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.roll = radiansToDegrees(motion.attitude.roll)
            self.pitch = radiansToDegrees(motion.attitude.pitch)
        }
    }

    func stopLevel() {
        motionManager.stopDeviceMotionUpdates()
    }
}

extension MotionProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading
    ) {
        let trueHeading = newHeading.trueHeading
        let magneticHeading = newHeading.magneticHeading
        MainActor.assumeIsolated {
            // trueHeading is negative when no location fix backs it up.
            self.heading =
                (isTrueNorth && trueHeading >= 0) ? trueHeading : magneticHeading
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            self.authorizationDenied = status == .denied || status == .restricted
        }
    }
}
