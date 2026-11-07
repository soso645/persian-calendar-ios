import Foundation

/// Month and weekday names per calendar and language.
///
/// The Android app resolves these through `Language.kt` plus 23 sets of string resources. This
/// port ships Persian, English and Arabic, so the names live here directly rather than going
/// through a string catalog — they are data, not UI copy, and keeping them together makes the
/// per-language variations (e.g. Arabic-in-Iran Persian month names) legible.
enum CalendarNames {

    static func months(for calendar: CalendarKind, language: AppLanguage) -> [String] {
        switch calendar {
        case .shamsi: persianMonths(language)
        case .islamic: islamicMonths(language)
        case .gregorian: gregorianMonths(language)
        case .nepali: nepaliMonths(language)
        }
    }

    /// Weekday names, Saturday-first to match ``WeekDay``.
    static func weekDays(_ language: AppLanguage) -> [String] {
        switch language {
        case .fa:
            // https://apll.ir/wp-content/uploads/2018/10/D-1394.pdf
            ["شنبه", "یک‌شنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنج‌شنبه", "جمعه"]
        case .ar:
            ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"]
        case .en:
            ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        }
    }

    static func weekDaysInitials(_ language: AppLanguage) -> [String] {
        switch language {
        case .fa: ["ش", "ی", "د", "س", "چ", "پ", "ج"]
        case .ar: ["س", "ح", "ن", "ث", "ر", "خ", "ج"]
        case .en: ["S", "S", "M", "T", "W", "T", "F"]
        }
    }

    // MARK: - Per calendar

    private static func persianMonths(_ language: AppLanguage) -> [String] {
        switch language {
        case .fa:
            [
                "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
                "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
            ]
        case .ar:
            [
                "فروردین", "أرديبهشت", "خرداد", "تیر", "مرداد", "شهریور",
                "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
            ]
        case .en:
            [
                "Farvardin", "Ordibehesht", "Khordad", "Tir", "Mordad", "Shahrivar",
                "Mehr", "Aban", "Azar", "Dey", "Bahman", "Esfand",
            ]
        }
    }

    private static func islamicMonths(_ language: AppLanguage) -> [String] {
        switch language {
        case .fa:
            [
                "مُحَرَّم", "صَفَر", "ربیع‌الاول", "ربیع‌الثانی", "جمادى‌الاولى", "جمادی‌الثانیه",
                "رجب", "شعبان", "رمضان", "شوال", "ذی‌القعده", "ذی‌الحجه",
            ]
        case .ar:
            [
                "محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الآخرة",
                "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
            ]
        case .en:
            [
                "Muharram", "Safar", "Rabi’ al-Awwal", "Rabi’ al-Thani",
                "Jumada al-Ula", "Jumada al-Akhirah",
                "Rajab", "Sha’ban", "Ramadan", "Shawwal", "Dhu al-Qi’dah", "Dhu al-Hijjah",
            ]
        }
    }

    private static func gregorianMonths(_ language: AppLanguage) -> [String] {
        switch language {
        case .fa:
            [
                "ژانویه", "فوریه", "مارس", "آوریل", "مه", "ژوئن",
                "ژوئیه", "اوت", "سپتامبر", "اکتبر", "نوامبر", "دسامبر",
            ]
        case .ar:
            [
                "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
                "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
            ]
        case .en:
            [
                "January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December",
            ]
        }
    }

    private static func nepaliMonths(_ language: AppLanguage) -> [String] {
        switch language {
        case .fa:
            [
                "بایساخ", "جیت", "آسار", "ساون", "بادرا", "آسوج",
                "کارتیک", "منسیر", "پوش", "ماگ", "فاگون", "چایت",
            ]
        case .ar:
            [
                "بيساخ", "جيث", "أساد", "ساون", "بادرا", "أسوج",
                "كارتيك", "مانسير", "بوش", "ماغ", "فالغون", "تشايت",
            ]
        case .en:
            [
                "Baishakh", "Jestha", "Ashadh", "Shrawan", "Bhadra", "Ashwin",
                "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra",
            ]
        }
    }
}

extension CalendarKind {
    /// Localization key for the calendar's own name.
    var titleKey: String {
        switch self {
        case .shamsi: "persian_calendar"
        case .islamic: "hijri_calendar"
        case .gregorian: "gregorian_calendar"
        case .nepali: "nepali_calendar"
        }
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.shamsi, .fa): "هجری شمسی"
        case (.shamsi, .ar): "هجري شمسي"
        case (.shamsi, .en): "Persian"
        case (.islamic, .fa): "هجری قمری"
        case (.islamic, .ar): "هجري قمري"
        case (.islamic, .en): "Hijri"
        case (.gregorian, .fa): "میلادی"
        case (.gregorian, .ar): "ميلادي"
        case (.gregorian, .en): "Gregorian"
        case (.nepali, .fa): "نپالی"
        case (.nepali, .ar): "نيبالي"
        case (.nepali, .en): "Nepali"
        }
    }
}
