import Foundation

// A Swift face for the vendored Astronomy Engine C library (see CAstronomy/README.md).
//
// The API deliberately mirrors the shape of the project's *Kotlin* edition, because the Android
// screens this app is ported from were written against that API. Keeping the names and argument
// order aligned makes the UI ports read as direct translations.
//
// The C library reports failures with status codes; the Kotlin one throws or returns null. Here,
// searches that can legitimately find nothing return `nil`, while a failure in a routine that
// should always succeed for valid input traps, since it indicates a programming error.

// MARK: - Errors

enum AstronomyError: Error, CustomStringConvertible {
    case failure(String, astro_status_t)

    var description: String {
        switch self {
        case let .failure(what, status): "Astronomy \(what) failed with status \(status.rawValue)"
        }
    }
}

@inline(__always)
private func require(_ status: astro_status_t, _ what: String) {
    precondition(status == ASTRO_SUCCESS, "Astronomy \(what) failed: status \(status.rawValue)")
}

// MARK: - Time

/// A moment in time, expressed as days since the J2000 epoch.
///
/// Wraps `astro_time_t`, which caches nutation terms alongside the timestamp, so passing one
/// around avoids recomputing them.
struct AstroTime: Hashable, Comparable, @unchecked Sendable {
    // `astro_time_t` is a plain struct of five doubles, hence the unchecked Sendable.
    fileprivate var c: astro_time_t

    fileprivate init(c: astro_time_t) { self.c = c }

    /// UT1/UTC days since the J2000 epoch.
    var ut: Double { c.ut }

    /// Terrestrial Time days since the J2000 epoch.
    var tt: Double { c.tt }

    /// - Parameter ut: days since J2000.
    init(ut: Double) {
        self.c = Astronomy_TimeFromDays(ut)
    }

    init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Double) {
        self.c = Astronomy_MakeTime(
            Int32(year), Int32(month), Int32(day), Int32(hour), Int32(minute), second)
    }

    static func fromMillisecondsSince1970(_ millis: Int) -> AstroTime {
        // J2000 is 2000-01-01T12:00:00Z, which is 946_728_000_000 ms after the Unix epoch.
        AstroTime(ut: (Double(millis) - 946_728_000_000) / 86_400_000)
    }

    func toMillisecondsSince1970() -> Int {
        Int((ut * 86_400_000).rounded()) + 946_728_000_000
    }

    var date: Date {
        Date(timeIntervalSince1970: Double(toMillisecondsSince1970()) / 1000)
    }

    func addDays(_ days: Double) -> AstroTime {
        AstroTime(c: Astronomy_AddDays(c, days))
    }

    static func < (lhs: AstroTime, rhs: AstroTime) -> Bool { lhs.ut < rhs.ut }
    static func == (lhs: AstroTime, rhs: AstroTime) -> Bool { lhs.ut == rhs.ut }
    func hash(into hasher: inout Hasher) { hasher.combine(ut) }
}

// MARK: - Simple value types

/// A location on the Earth's surface.
struct Observer: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let height: Double

    init(_ latitude: Double, _ longitude: Double, _ height: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.height = height
    }

    fileprivate var c: astro_observer_t {
        Astronomy_MakeObserver(latitude, longitude, height)
    }
}

/// A 3D Cartesian vector with an associated time, in AU.
struct AstroVector: Sendable {
    let x: Double
    let y: Double
    let z: Double
    let t: AstroTime

    fileprivate init(c: astro_vector_t, _ what: String) {
        require(c.status, what)
        self.x = c.x
        self.y = c.y
        self.z = c.z
        self.t = AstroTime(c: c.t)
    }

    init(x: Double, y: Double, z: Double, t: AstroTime) {
        self.x = x
        self.y = y
        self.z = z
        self.t = t
    }

    func length() -> Double { (x * x + y * y + z * z).squareRoot() }

    fileprivate var c: astro_vector_t {
        astro_vector_t(status: ASTRO_SUCCESS, x: x, y: y, z: z, t: t.c)
    }
}

/// Spherical coordinates: latitude and longitude in degrees, distance in AU.
struct Spherical: Sendable {
    let lat: Double
    let lon: Double
    let dist: Double

    init(lat: Double, lon: Double, dist: Double) {
        self.lat = lat
        self.lon = lon
        self.dist = dist
    }

    fileprivate init(c: astro_spherical_t, _ what: String) {
        require(c.status, what)
        self.lat = c.lat
        self.lon = c.lon
        self.dist = c.dist
    }
}

/// Ecliptic coordinates of a body.
struct Ecliptic: Sendable {
    /// The Cartesian ecliptic vector.
    let vec: AstroVector
    /// Ecliptic latitude in degrees.
    let elat: Double
    /// Ecliptic longitude in degrees.
    let elon: Double

    fileprivate init(c: astro_ecliptic_t, _ what: String) {
        require(c.status, what)
        self.vec = AstroVector(c: c.vec, what)
        self.elat = c.elat
        self.elon = c.elon
    }
}

/// Equatorial coordinates of a body.
struct Equatorial: Sendable {
    /// Right ascension in sidereal hours.
    let ra: Double
    /// Declination in degrees.
    let dec: Double
    /// Distance in AU.
    let dist: Double
    let vec: AstroVector

    fileprivate init(c: astro_equatorial_t, _ what: String) {
        require(c.status, what)
        self.ra = c.ra
        self.dec = c.dec
        self.dist = c.dist
        self.vec = AstroVector(c: c.vec, what)
    }
}

/// Horizontal coordinates of a body as seen by an observer.
struct Topocentric: Sendable {
    /// Compass direction of the body in degrees, 0 = north, increasing clockwise.
    let azimuth: Double
    /// Angle above (positive) or below (negative) the horizon, in degrees.
    let altitude: Double
    let ra: Double
    let dec: Double

    fileprivate init(c: astro_horizon_t) {
        self.azimuth = c.azimuth
        self.altitude = c.altitude
        self.ra = c.ra
        self.dec = c.dec
    }
}

/// A 3x3 rotation matrix for converting between coordinate systems.
struct RotationMatrix: Sendable {
    /// Row-major 3x3 matrix.
    let rot: [[Double]]

    fileprivate init(c: astro_rotation_t, _ what: String) {
        require(c.status, what)
        let r = c.rot
        self.rot = [
            [r.0.0, r.0.1, r.0.2],
            [r.1.0, r.1.1, r.1.2],
            [r.2.0, r.2.1, r.2.2],
        ]
    }

    /// Re-express this rotation about one of its own axes, rotated by `angle` degrees.
    ///
    /// - Parameter axis: 0 = x, 1 = y, 2 = z.
    func pivot(_ axis: Int, _ angle: Double) -> RotationMatrix {
        RotationMatrix(c: Astronomy_Pivot(c, Int32(axis), angle), "pivot")
    }

    func rotate(_ vector: AstroVector) -> AstroVector { rotateVector(self, vector) }

    var inverse: RotationMatrix {
        RotationMatrix(c: Astronomy_InverseRotation(c), "inverseRotation")
    }

    fileprivate var c: astro_rotation_t {
        var result = astro_rotation_t()
        result.status = ASTRO_SUCCESS
        result.rot.0 = (rot[0][0], rot[0][1], rot[0][2])
        result.rot.1 = (rot[1][0], rot[1][1], rot[1][2])
        result.rot.2 = (rot[2][0], rot[2][1], rot[2][2])
        return result
    }
}

// MARK: - Enums

enum Body: Sendable, CaseIterable {
    case mercury, venus, earth, mars, jupiter, saturn, uranus, neptune, pluto, sun, moon

    fileprivate var c: astro_body_t {
        switch self {
        case .mercury: BODY_MERCURY
        case .venus: BODY_VENUS
        case .earth: BODY_EARTH
        case .mars: BODY_MARS
        case .jupiter: BODY_JUPITER
        case .saturn: BODY_SATURN
        case .uranus: BODY_URANUS
        case .neptune: BODY_NEPTUNE
        case .pluto: BODY_PLUTO
        case .sun: BODY_SUN
        case .moon: BODY_MOON
        }
    }
}

/// Whether to correct for the light-travel-time aberration.
enum Aberration: Sendable {
    case corrected, none

    fileprivate var c: astro_aberration_t {
        switch self {
        case .corrected: ABERRATION
        case .none: NO_ABERRATION
        }
    }
}

/// Which equator to express coordinates against.
enum EquatorEpoch: Sendable {
    case j2000, ofDate

    fileprivate var c: astro_equator_date_t {
        switch self {
        case .j2000: EQUATOR_J2000
        case .ofDate: EQUATOR_OF_DATE
        }
    }
}

/// Whether to correct for atmospheric refraction.
enum Refraction: Sendable {
    case none, normal, jplHor

    fileprivate var c: astro_refraction_t {
        switch self {
        case .none: REFRACTION_NONE
        case .normal: REFRACTION_NORMAL
        case .jplHor: REFRACTION_JPLHOR
        }
    }
}

/// Whether to search for a rise or a set event.
enum Direction: Sendable {
    case rise, set

    fileprivate var c: astro_direction_t {
        switch self {
        case .rise: DIRECTION_RISE
        case .set: DIRECTION_SET
        }
    }
}

enum NodeEventKind: Sendable {
    case invalid, ascending, descending

    fileprivate init(c: astro_node_kind_t) {
        switch c {
        case ASCENDING_NODE: self = .ascending
        case DESCENDING_NODE: self = .descending
        default: self = .invalid
        }
    }
}

enum EclipseKind: Sendable {
    case none, penumbral, partial, annular, total

    fileprivate init(c: astro_eclipse_kind_t) {
        switch c {
        case ECLIPSE_PENUMBRAL: self = .penumbral
        case ECLIPSE_PARTIAL: self = .partial
        case ECLIPSE_ANNULAR: self = .annular
        case ECLIPSE_TOTAL: self = .total
        default: self = .none
        }
    }
}

// MARK: - Result types

struct SeasonsInfo: Sendable {
    let marchEquinox: AstroTime
    let juneSolstice: AstroTime
    let septemberEquinox: AstroTime
    let decemberSolstice: AstroTime
}

struct LibrationInfo: Sendable {
    /// Sub-Earth libration ecliptic latitude angle, in degrees.
    let elat: Double
    /// Sub-Earth libration ecliptic longitude angle, in degrees.
    let elon: Double
    /// Moon's geocentric ecliptic latitude, in degrees.
    let mlat: Double
    /// Moon's geocentric ecliptic longitude, in degrees.
    let mlon: Double
    /// Distance between the centers of the Earth and Moon, in kilometers.
    let distKm: Double
    /// The apparent angular diameter of the Moon, in degrees.
    let diamDeg: Double
}

struct NodeEventInfo: Sendable {
    let time: AstroTime
    let kind: NodeEventKind
}

struct ElongationInfo: Sendable {
    let time: AstroTime
    let elongation: Double
    let eclipticSeparation: Double
}

struct LunarEclipseInfo: Sendable {
    let kind: EclipseKind
    let obscuration: Double
    let peak: AstroTime
    /// Semi-duration of the penumbral phase in minutes.
    let sdPenum: Double
    /// Semi-duration of the partial phase in minutes, or 0 if none.
    let sdPartial: Double
    /// Semi-duration of the total phase in minutes, or 0 if none.
    let sdTotal: Double
}

struct GlobalSolarEclipseInfo: Sendable {
    let kind: EclipseKind
    let obscuration: Double
    let peak: AstroTime
    /// Distance between the Moon's shadow axis and the Earth's center, in kilometers.
    let distance: Double
    /// Latitude where the shadow axis touches the Earth, if it does.
    let latitude: Double
    /// Longitude where the shadow axis touches the Earth, if it does.
    let longitude: Double
}

struct EclipseEvent: Sendable {
    let time: AstroTime
    /// Altitude of the Sun above the horizon, in degrees.
    let altitude: Double

    fileprivate init(c: astro_eclipse_event_t) {
        self.time = AstroTime(c: c.time)
        self.altitude = c.altitude
    }
}

struct LocalSolarEclipseInfo: Sendable {
    let kind: EclipseKind
    let obscuration: Double
    let partialBegin: EclipseEvent
    let totalBegin: EclipseEvent
    let peak: EclipseEvent
    let totalEnd: EclipseEvent
    let partialEnd: EclipseEvent
}

// MARK: - Angle helpers

func degreesToRadians(_ degrees: Double) -> Double { degrees * .pi / 180 }
func radiansToDegrees(_ radians: Double) -> Double { radians * 180 / .pi }

// MARK: - Positions

/// Ecliptic coordinates of the center of the Sun as seen from the Earth.
func sunPosition(_ time: AstroTime) -> Ecliptic {
    Ecliptic(c: Astronomy_SunPosition(time.c), "sunPosition")
}

/// Geocentric position of a body, corrected for light travel time.
func geoVector(_ body: Body, _ time: AstroTime, _ aberration: Aberration) -> AstroVector {
    AstroVector(c: Astronomy_GeoVector(body.c, time.c, aberration.c), "geoVector")
}

/// Heliocentric position of a body.
func helioVector(_ body: Body, _ time: AstroTime) -> AstroVector {
    AstroVector(c: Astronomy_HelioVector(body.c, time.c), "helioVector")
}

/// Equatorial coordinates of a body as seen by an observer.
func equator(
    _ body: Body,
    _ time: AstroTime,
    _ observer: Observer,
    _ epoch: EquatorEpoch,
    _ aberration: Aberration
) -> Equatorial {
    var t = time.c
    return Equatorial(
        c: Astronomy_Equator(body.c, &t, observer.c, epoch.c, aberration.c), "equator")
}

/// Horizontal coordinates for given equatorial coordinates and observer.
func horizon(
    _ time: AstroTime,
    _ observer: Observer,
    _ ra: Double,
    _ dec: Double,
    _ refraction: Refraction
) -> Topocentric {
    var t = time.c
    return Topocentric(c: Astronomy_Horizon(&t, observer.c, ra, dec, refraction.c))
}

/// Geocentric ecliptic coordinates of the Moon, in true-of-date coordinates.
func eclipticGeoMoon(_ time: AstroTime) -> Spherical {
    Spherical(c: Astronomy_EclipticGeoMoon(time.c), "eclipticGeoMoon")
}

/// Libration angles and apparent size of the Moon.
func libration(_ time: AstroTime) -> LibrationInfo {
    let c = Astronomy_Libration(time.c)
    return LibrationInfo(
        elat: c.elat, elon: c.elon, mlat: c.mlat, mlon: c.mlon,
        distKm: c.dist_km, diamDeg: c.diam_deg)
}

/// Angular separation between a body and the Sun as seen from the Earth.
func elongation(_ body: Body, _ time: AstroTime) -> ElongationInfo? {
    let c = Astronomy_Elongation(body.c, time.c)
    guard c.status == ASTRO_SUCCESS else { return nil }
    return ElongationInfo(
        time: AstroTime(c: c.time),
        elongation: c.elongation,
        eclipticSeparation: c.ecliptic_separation)
}

/// Greenwich apparent sidereal time, in sidereal hours.
func siderealTime(_ time: AstroTime) -> Double {
    var t = time.c
    return Astronomy_SiderealTime(&t)
}

/// Convert a J2000 equatorial vector to true ecliptic-of-date coordinates.
func equatorialToEcliptic(_ eqj: AstroVector) -> Ecliptic {
    Ecliptic(c: Astronomy_Ecliptic(eqj.c), "equatorialToEcliptic")
}

/// Apply a rotation matrix to a vector.
func rotateVector(_ rotation: RotationMatrix, _ vector: AstroVector) -> AstroVector {
    AstroVector(c: Astronomy_RotateVector(rotation.c, vector.c), "rotateVector")
}

// MARK: - Rotation matrices

/// True ecliptic of date to equatorial of date.
func rotationEctEqd(_ time: AstroTime) -> RotationMatrix {
    var t = time.c
    return RotationMatrix(c: Astronomy_Rotation_ECT_EQD(&t), "rotationEctEqd")
}

/// Equatorial of date to horizontal.
func rotationEqdHor(_ time: AstroTime, _ observer: Observer) -> RotationMatrix {
    var t = time.c
    return RotationMatrix(c: Astronomy_Rotation_EQD_HOR(&t, observer.c), "rotationEqdHor")
}

/// J2000 equatorial to equatorial of date.
func rotationEqjEqd(_ time: AstroTime) -> RotationMatrix {
    var t = time.c
    return RotationMatrix(c: Astronomy_Rotation_EQJ_EQD(&t), "rotationEqjEqd")
}

// MARK: - Searches

/// The equinoxes and solstices of a given Gregorian calendar year.
func seasons(_ year: Int) -> SeasonsInfo {
    let c = Astronomy_Seasons(Int32(year))
    require(c.status, "seasons")
    return SeasonsInfo(
        marchEquinox: AstroTime(c: c.mar_equinox),
        juneSolstice: AstroTime(c: c.jun_solstice),
        septemberEquinox: AstroTime(c: c.sep_equinox),
        decemberSolstice: AstroTime(c: c.dec_solstice))
}

/// The next time a body rises or sets as seen by an observer.
///
/// Returns `nil` if the event does not occur within `limitDays` — which genuinely happens near the
/// poles, where a body can stay up or down for months.
func searchRiseSet(
    _ body: Body,
    _ observer: Observer,
    _ direction: Direction,
    _ startTime: AstroTime,
    _ limitDays: Double
) -> AstroTime? {
    let c = Astronomy_SearchRiseSetEx(
        body.c, observer.c, direction.c, startTime.c, limitDays, 0.0)
    guard c.status == ASTRO_SUCCESS else { return nil }
    return AstroTime(c: c.time)
}

/// The next time the Moon crosses the ecliptic plane, at or after the given time.
func moonNodesAfter(_ time: AstroTime) -> NodeEventInfo {
    let c = Astronomy_SearchMoonNode(time.c)
    require(c.status, "moonNodesAfter")
    return NodeEventInfo(time: AstroTime(c: c.time), kind: NodeEventKind(c: c.kind))
}

/// Successive Moon node crossings starting at or after `time`, alternating ascending/descending.
///
/// The Kotlin edition exposes this as an infinite sequence; here it is a lazy `Sequence` so
/// callers can `prefix` or `first(where:)` without computing more crossings than they need.
func moonNodeSequence(after time: AstroTime) -> some Sequence<NodeEventInfo> {
    sequence(state: Optional<astro_node_event_t>.none) { previous -> NodeEventInfo? in
        let next: astro_node_event_t
        if let last = previous {
            next = Astronomy_NextMoonNode(last)
        } else {
            next = Astronomy_SearchMoonNode(time.c)
        }
        guard next.status == ASTRO_SUCCESS else { return nil }
        previous = next
        return NodeEventInfo(time: AstroTime(c: next.time), kind: NodeEventKind(c: next.kind))
    }
}

func searchLunarEclipse(_ startTime: AstroTime) -> LunarEclipseInfo? {
    let c = Astronomy_SearchLunarEclipse(startTime.c)
    guard c.status == ASTRO_SUCCESS else { return nil }
    return LunarEclipseInfo(
        kind: EclipseKind(c: c.kind),
        obscuration: c.obscuration,
        peak: AstroTime(c: c.peak),
        sdPenum: c.sd_penum,
        sdPartial: c.sd_partial,
        sdTotal: c.sd_total)
}

func searchGlobalSolarEclipse(_ startTime: AstroTime) -> GlobalSolarEclipseInfo? {
    let c = Astronomy_SearchGlobalSolarEclipse(startTime.c)
    guard c.status == ASTRO_SUCCESS else { return nil }
    return GlobalSolarEclipseInfo(
        kind: EclipseKind(c: c.kind),
        obscuration: c.obscuration,
        peak: AstroTime(c: c.peak),
        distance: c.distance,
        latitude: c.latitude,
        longitude: c.longitude)
}

func searchLocalSolarEclipse(
    _ startTime: AstroTime, _ observer: Observer
) -> LocalSolarEclipseInfo? {
    let c = Astronomy_SearchLocalSolarEclipse(startTime.c, observer.c)
    guard c.status == ASTRO_SUCCESS else { return nil }
    return LocalSolarEclipseInfo(
        kind: EclipseKind(c: c.kind),
        obscuration: c.obscuration,
        partialBegin: EclipseEvent(c: c.partial_begin),
        totalBegin: EclipseEvent(c: c.total_begin),
        peak: EclipseEvent(c: c.peak),
        totalEnd: EclipseEvent(c: c.total_end),
        partialEnd: EclipseEvent(c: c.partial_end))
}

/// Find a time in `[t1, t2]` at which `f` crosses zero.
///
/// `f` must be continuous over the interval and have opposite signs at its ends.
func search(
    t1: AstroTime,
    t2: AstroTime,
    toleranceSeconds: Double,
    _ f: (AstroTime) -> Double
) -> AstroTime? {
    // The C callback takes an opaque context pointer, so the Swift closure is passed through as
    // one. It cannot escape the call, so a plain pointer to a local box is safe here.
    final class Box {
        let f: (AstroTime) -> Double
        init(_ f: @escaping (AstroTime) -> Double) { self.f = f }
    }

    return withoutActuallyEscaping(f) { escapableF -> AstroTime? in
        let box = Box(escapableF)
        return withExtendedLifetime(box) { () -> AstroTime? in
            let context = Unmanaged.passUnretained(box).toOpaque()
            let callback: @convention(c) (UnsafeMutableRawPointer?, astro_time_t)
                -> astro_func_result_t = { context, time in
                    guard let context else {
                        return astro_func_result_t(status: ASTRO_INVALID_PARAMETER, value: 0)
                    }
                    let box = Unmanaged<Box>.fromOpaque(context).takeUnretainedValue()
                    let value = box.f(AstroTime(c: time))
                    return astro_func_result_t(status: ASTRO_SUCCESS, value: value)
                }
            let c = Astronomy_Search(callback, context, t1.c, t2.c, toleranceSeconds)
            guard c.status == ASTRO_SUCCESS else { return nil }
            return AstroTime(c: c.time)
        }
    }
}
