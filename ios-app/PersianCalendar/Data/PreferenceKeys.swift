import Foundation

/// UserDefaults keys, matching the Android `SharedPreferences` names.
///
/// The strings are kept identical to the Kotlin `PREF_*` constants so that the two apps read the
/// same shape of settings, and so a future import/export feature is straightforward.
enum PreferenceKey {
    static let mainCalendar = "mainCalendarType"
    static let otherCalendars = "otherCalendarTypes"
    static let secondaryCalendarInTable = "secondaryCalendarShown"
    static let prayTimeMethod = "SelectedPrayTimeMethod"
    static let highLatitudesMethod = "SelectedHighLatitudesMethod"
    static let midnightMethod = "SelectedMidnightMethod"
    static let asrHanafiJuristic = "AsrHanafiJuristic"
    static let hijriOffset = "islamic_offset"
    static let latitude = "Latitude"
    static let longitude = "Longitude"
    static let altitude = "Altitude"
    static let selectedLocation = "Location"
    static let geocodedCityName = "cityname"
    static let iranTime = "IranTime"
    static let localNumeral = "PersianDigits"
    static let numericalDatePreferred = "numericalDatePreferred"
    static let astronomicalFeatures = "astronomicalFeatures"
    static let showMoonInScorpio = "moonInScorpio"
    static let showWeekOfYearNumber = "showWeekOfYearNumber"
    static let appLanguage = "AppLanguage"
    static let easternGregorianArabicMonths = "EasternGregorianArabicMonths"
    static let englishGregorianPersianMonths = "EnglishGregorianPersianMonths"
    static let azeriAlternativePersianMonths = "AzeriAlternativePersianMonths"
    static let englishWeekdaysInIranEnglish = "EnglishWeekDaysInIranEnglish"
    static let iso8601DateFormat = "Iso8601DateFormat"
    static let theme = "Theme"
    static let redHolidays = "RedHolidays"
    static let boldFont = "BoldFont"
    static let holidayTypes = "holiday_types"
    static let weekStart = "WeekStart"
    static let weekEnds = "WeekEnds"
    static let shiftWorkStartingJdn = "ShiftWorkJdn"
    static let shiftWorkSetting = "ShiftWorkSetting"
    static let shiftWorkRecurs = "ShiftWorkRecurs"
    static let dismissedTimes = "DisableOwghat"
    static let showQiblaInCompass = "showQibla"
    static let trueNorthInCompass = "trueNorth"
    static let athanAlarm = "AthanAlarm"
    static let athanGap = "AthanGap"
    static let athanName = "AthanName"
    static let athanVibration = "NotificationAthanVibration"
    static let athanVolume = "athanVolume"
    static let showDeviceCalendarEvents = "showDeviceCalendarEvents"
    static let calculatorInput = "CalculatorInput"
}

/// Defaults, matching the Android `DEFAULT_*` constants.
enum PreferenceDefault {
    static let city = "CUSTOM"
    static let prayTimeMethod = CalculationMethod.Tehran
    static let highLatitudesMethod = HighLatitudesMethod.nightMiddle
    static let iranTime = false
    static let localNumeral = true
    static let numericalDatePreferred = false
    static let hijriOffset = 0
    static let secondaryCalendarInTable = false
    static let redHolidays = true
    static let boldFont = false
    static let astronomicalFeatures = false
    static let showMoonInScorpio = false
    static let showWeekOfYearNumber = false
    static let athanVolume = 3
    static let athanVibration = true
    static let showDeviceCalendarEvents = false
}
