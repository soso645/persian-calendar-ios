import Foundation
import Observation

/// The app's settings, backed by `UserDefaults`.
///
/// Replaces the Android app's `global/Global.kt`, which holds its settings in Compose
/// `mutableStateOf` globals refreshed from `SharedPreferences`. Here the values live in one
/// `@Observable` object injected through the SwiftUI environment, so views update automatically.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let resolvedLanguage =
            defaults.string(forKey: PreferenceKey.appLanguage)
            .flatMap(AppLanguage.init(rawValue:)) ?? .deviceDefault
        let resolvedMain =
            defaults.string(forKey: PreferenceKey.mainCalendar)
            .flatMap(CalendarKind.init(rawValue:)) ?? resolvedLanguage.preferredCalendar
        self.language = resolvedLanguage
        self.mainCalendar = resolvedMain
        // Default to the other two commonly shown calendars, never repeating the main one.
        self.otherCalendars =
            defaults.string(forKey: PreferenceKey.otherCalendars)
            .map { $0.split(separator: ",").compactMap { CalendarKind(rawValue: String($0)) } }
            ?? [.shamsi, .gregorian, .islamic].filter { $0 != resolvedMain }
        self.secondaryCalendarInTable = defaults.bool(
            forKey: PreferenceKey.secondaryCalendarInTable,
            default: PreferenceDefault.secondaryCalendarInTable)
        self.iranTime = defaults.bool(
            forKey: PreferenceKey.iranTime, default: PreferenceDefault.iranTime)
        self.localNumeral = defaults.bool(
            forKey: PreferenceKey.localNumeral, default: PreferenceDefault.localNumeral)
        self.numericalDatePreferred = defaults.bool(
            forKey: PreferenceKey.numericalDatePreferred,
            default: PreferenceDefault.numericalDatePreferred)
        self.astronomicalFeatures = defaults.bool(
            forKey: PreferenceKey.astronomicalFeatures,
            default: PreferenceDefault.astronomicalFeatures)
        self.showMoonInScorpio = defaults.bool(
            forKey: PreferenceKey.showMoonInScorpio, default: PreferenceDefault.showMoonInScorpio)
        self.showWeekOfYearNumber = defaults.bool(
            forKey: PreferenceKey.showWeekOfYearNumber,
            default: PreferenceDefault.showWeekOfYearNumber)
        self.redHolidays = defaults.bool(
            forKey: PreferenceKey.redHolidays, default: PreferenceDefault.redHolidays)
        self.boldFont = defaults.bool(
            forKey: PreferenceKey.boldFont, default: PreferenceDefault.boldFont)
        self.iso8601DateFormat = defaults.bool(forKey: PreferenceKey.iso8601DateFormat)
        self.showDeviceCalendarEvents = defaults.bool(
            forKey: PreferenceKey.showDeviceCalendarEvents,
            default: PreferenceDefault.showDeviceCalendarEvents)
        self.hijriOffset = defaults.integer(
            forKey: PreferenceKey.hijriOffset, default: PreferenceDefault.hijriOffset)

        self.prayTimeMethod =
            defaults.string(forKey: PreferenceKey.prayTimeMethod)
            .flatMap(CalculationMethod.init(rawValue:)) ?? PreferenceDefault.prayTimeMethod
        self.highLatitudesMethod =
            defaults.string(forKey: PreferenceKey.highLatitudesMethod)
            .flatMap(HighLatitudesMethod.init(rawValue:)) ?? PreferenceDefault.highLatitudesMethod
        self.midnightMethod =
            defaults.string(forKey: PreferenceKey.midnightMethod)
            .flatMap(MidnightMethod.init(rawValue:))
        self.asrHanafiJuristic = defaults.bool(forKey: PreferenceKey.asrHanafiJuristic)

        self.selectedLocation = defaults.string(forKey: PreferenceKey.selectedLocation)
            ?? PreferenceDefault.city
        self.geocodedCityName = defaults.string(forKey: PreferenceKey.geocodedCityName)
        self.storedLatitude = defaults.optionalDouble(forKey: PreferenceKey.latitude)
        self.storedLongitude = defaults.optionalDouble(forKey: PreferenceKey.longitude)
        self.storedAltitude = defaults.double(forKey: PreferenceKey.altitude)

        self.holidayTypes =
            (defaults.array(forKey: PreferenceKey.holidayTypes) as? [String]).map(Set.init)
            ?? EventsRepository.defaultEnabledTypes(
                isIranExclusiveLanguage: true, isAfghanistanExclusiveLanguage: false)

        self.weekStart =
            defaults.optionalInt(forKey: PreferenceKey.weekStart)
            .flatMap(WeekDay.init(rawValue:)) ?? .saturday
        self.weekEnds =
            (defaults.array(forKey: PreferenceKey.weekEnds) as? [Int])
            .map { Set($0.compactMap(WeekDay.init(rawValue:))) } ?? [.friday]

        self.shiftWorkRecurs = defaults.bool(forKey: PreferenceKey.shiftWorkRecurs, default: true)
        self.shiftWorkStartingJdn = defaults.optionalInt(
            forKey: PreferenceKey.shiftWorkStartingJdn).map(Jdn.init)
        self.shiftWorkRecords = ShiftWorkSettings.parse(
            defaults.string(forKey: PreferenceKey.shiftWorkSetting) ?? "")

        self.showQiblaInCompass = defaults.bool(
            forKey: PreferenceKey.showQiblaInCompass, default: true)
        self.trueNorthInCompass = defaults.bool(forKey: PreferenceKey.trueNorthInCompass)

        self.athanAlarm =
            (defaults.array(forKey: PreferenceKey.athanAlarm) as? [String]).map(Set.init) ?? []
        self.athanGapMinutes = defaults.double(forKey: PreferenceKey.athanGap)
        self.dismissedTimes =
            (defaults.array(forKey: PreferenceKey.dismissedTimes) as? [String]).map(Set.init) ?? []

        self.athanSound =
            defaults.string(forKey: PreferenceKey.athanName)
            .flatMap(AthanSound.init(rawValue:)) ?? .standard
        self.calculatorInput = defaults.string(forKey: PreferenceKey.calculatorInput) ?? ""

        // String lookups must point at the chosen language before any view renders.
        Bundle.setAppLanguage(resolvedLanguage)
        // The Islamic calendar's global configuration has to reflect the stored offset before any
        // date is converted.
        IslamicDate.islamicOffset = hijriOffset
        rebuildEventsRepository()
    }

    // MARK: - Stored settings

    var language: AppLanguage { didSet {
        persist(language.rawValue, PreferenceKey.appLanguage)
        Bundle.setAppLanguage(language)
        rebuildEventsRepository() } }
    var mainCalendar: CalendarKind { didSet {
        persist(mainCalendar.rawValue, PreferenceKey.mainCalendar)
        // The main calendar heads the day details on its own; showing it again below is noise.
        if otherCalendars.contains(mainCalendar) {
            otherCalendars = otherCalendars.filter { $0 != mainCalendar }
        }
        if let oldValue = Optional(oldValue), oldValue != mainCalendar,
            !otherCalendars.contains(oldValue)
        {
            otherCalendars.insert(oldValue, at: 0)
        } } }
    var otherCalendars: [CalendarKind] { didSet {
        persist(otherCalendars.map(\.rawValue).joined(separator: ","), PreferenceKey.otherCalendars)
        rebuildEventsRepository() } }
    var secondaryCalendarInTable: Bool { didSet {
        persist(secondaryCalendarInTable, PreferenceKey.secondaryCalendarInTable) } }
    var iranTime: Bool { didSet { persist(iranTime, PreferenceKey.iranTime) } }
    var localNumeral: Bool { didSet { persist(localNumeral, PreferenceKey.localNumeral) } }
    var numericalDatePreferred: Bool { didSet {
        persist(numericalDatePreferred, PreferenceKey.numericalDatePreferred) } }
    var astronomicalFeatures: Bool { didSet {
        persist(astronomicalFeatures, PreferenceKey.astronomicalFeatures) } }
    var showMoonInScorpio: Bool { didSet {
        persist(showMoonInScorpio, PreferenceKey.showMoonInScorpio) } }
    var showWeekOfYearNumber: Bool { didSet {
        persist(showWeekOfYearNumber, PreferenceKey.showWeekOfYearNumber) } }
    var redHolidays: Bool { didSet { persist(redHolidays, PreferenceKey.redHolidays) } }
    var boldFont: Bool { didSet { persist(boldFont, PreferenceKey.boldFont) } }
    var iso8601DateFormat: Bool { didSet {
        persist(iso8601DateFormat, PreferenceKey.iso8601DateFormat) } }
    var showDeviceCalendarEvents: Bool { didSet {
        persist(showDeviceCalendarEvents, PreferenceKey.showDeviceCalendarEvents) } }

    var hijriOffset: Int { didSet {
        persist(hijriOffset, PreferenceKey.hijriOffset)
        IslamicDate.islamicOffset = hijriOffset } }

    var prayTimeMethod: CalculationMethod { didSet {
        persist(prayTimeMethod.rawValue, PreferenceKey.prayTimeMethod) } }
    var highLatitudesMethod: HighLatitudesMethod { didSet {
        persist(highLatitudesMethod.rawValue, PreferenceKey.highLatitudesMethod) } }
    var midnightMethod: MidnightMethod? { didSet {
        persist(midnightMethod?.rawValue, PreferenceKey.midnightMethod) } }
    var asrHanafiJuristic: Bool { didSet {
        persist(asrHanafiJuristic, PreferenceKey.asrHanafiJuristic) } }

    var selectedLocation: String { didSet {
        persist(selectedLocation, PreferenceKey.selectedLocation) } }
    var geocodedCityName: String? { didSet {
        persist(geocodedCityName, PreferenceKey.geocodedCityName) } }
    private var storedLatitude: Double? { didSet {
        persist(storedLatitude, PreferenceKey.latitude) } }
    private var storedLongitude: Double? { didSet {
        persist(storedLongitude, PreferenceKey.longitude) } }
    private var storedAltitude: Double { didSet {
        persist(storedAltitude, PreferenceKey.altitude) } }

    var holidayTypes: Set<String> { didSet {
        persist(Array(holidayTypes), PreferenceKey.holidayTypes)
        rebuildEventsRepository() } }

    var weekStart: WeekDay { didSet { persist(weekStart.rawValue, PreferenceKey.weekStart) } }
    var weekEnds: Set<WeekDay> { didSet {
        persist(weekEnds.map(\.rawValue), PreferenceKey.weekEnds) } }

    var shiftWorkRecurs: Bool { didSet {
        persist(shiftWorkRecurs, PreferenceKey.shiftWorkRecurs) } }
    var shiftWorkStartingJdn: Jdn? { didSet {
        persist(shiftWorkStartingJdn?.value, PreferenceKey.shiftWorkStartingJdn) } }
    var shiftWorkRecords: [ShiftWorkRecord] { didSet {
        persist(shiftWork.serialized, PreferenceKey.shiftWorkSetting) } }

    var showQiblaInCompass: Bool { didSet {
        persist(showQiblaInCompass, PreferenceKey.showQiblaInCompass) } }
    var trueNorthInCompass: Bool { didSet {
        persist(trueNorthInCompass, PreferenceKey.trueNorthInCompass) } }

    var athanAlarm: Set<String> { didSet { persist(Array(athanAlarm), PreferenceKey.athanAlarm) } }
    var athanGapMinutes: Double { didSet { persist(athanGapMinutes, PreferenceKey.athanGap) } }
    var dismissedTimes: Set<String> { didSet {
        persist(Array(dismissedTimes), PreferenceKey.dismissedTimes) } }

    var athanSound: AthanSound { didSet {
        persist(athanSound.rawValue, PreferenceKey.athanName) } }

    var calculatorInput: String { didSet {
        persist(calculatorInput, PreferenceKey.calculatorInput) } }

    // MARK: - Derived

    /// The stored location, or nil when the user hasn't set one.
    var coordinates: Coordinates? {
        get {
            guard let storedLatitude, let storedLongitude else { return nil }
            return Coordinates(
                latitude: storedLatitude, longitude: storedLongitude, elevation: storedAltitude)
        }
        set {
            storedLatitude = newValue?.latitude
            storedLongitude = newValue?.longitude
            storedAltitude = newValue?.elevation ?? 0
        }
    }

    var numeral: Numeral { localNumeral ? language.preferredNumeral : .arabic }

    var enabledCalendars: [CalendarKind] { [mainCalendar] + otherCalendars }

    var asrMethod: AsrMethod { asrHanafiJuristic ? .hanafi : .standard }

    var shiftWork: ShiftWorkSettings {
        ShiftWorkSettings(
            recurs: shiftWorkRecurs, startingJdn: shiftWorkStartingJdn, records: shiftWorkRecords)
    }

    /// The active event set. Rebuilt when any setting it depends on changes, since constructing it
    /// filters the whole event table.
    private(set) var eventsRepository = EventsRepository.empty()

    private func rebuildEventsRepository() {
        eventsRepository = EventsRepository(
            enabledTypes: holidayTypes,
            enabledCalendars: enabledCalendars,
            numeral: numeral,
            isIranExclusiveLanguage: language.isIranExclusive,
            isAfghanistanExclusiveLanguage: language.isAfghanistanExclusive,
            isPersianOrDariLanguage: language.isPersianOrDari,
            mightPreferUmmAlquraIslamicCalendar: language.mightPreferUmmAlquraIslamicCalendar)
        // The repository resets the Islamic tabulation, so re-apply the user's offset after it.
        IslamicDate.islamicOffset = hijriOffset
    }

    /// Prayer times for a day at the stored location, or nil without one.
    ///
    /// Times come out in `timeZone`'s clock, which defaults to the device's — so a location
    /// abroad legitimately produces times that wrap past midnight, exactly as on Android.
    func prayTimes(for jdn: Jdn, timeZone: TimeZone? = nil) -> PrayTimes? {
        guard let coordinates else { return nil }
        let civil = jdn.toCivilDate()
        let timeZone =
            timeZone
            ?? (iranTime
                ? (TimeZone(identifier: EventsRepository.iranTimeZoneIdentifier) ?? .current)
                : TimeZone.current)
        let offset = Double(timeZone.secondsFromGMT(for: jdn.toDate(setIranTime: iranTime))) / 3600
        return PrayTimes(
            method: prayTimeMethod,
            year: civil.year, month: civil.month, dayOfMonth: civil.dayOfMonth,
            offset: offset,
            coordinates: coordinates,
            asrMethod: asrMethod,
            highLatitudesMethod: highLatitudesMethod,
            midnightMethod: midnightMethod ?? prayTimeMethod.defaultMidnight)
    }

    // MARK: - Persistence

    private func persist(_ value: Any?, _ key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

extension UserDefaults {
    /// `bool(forKey:)` returns false for a missing key, which is wrong when the default is true.
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }

    func integer(forKey key: String, default defaultValue: Int) -> Int {
        object(forKey: key) == nil ? defaultValue : integer(forKey: key)
    }

    func optionalInt(forKey key: String) -> Int? {
        object(forKey: key) == nil ? nil : integer(forKey: key)
    }

    func optionalDouble(forKey key: String) -> Double? {
        object(forKey: key) == nil ? nil : double(forKey: key)
    }
}
