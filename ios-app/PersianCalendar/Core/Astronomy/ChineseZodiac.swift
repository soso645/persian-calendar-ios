import Foundation

/// The twelve-animal year cycle.
///
/// موش و بقر و پلنگ و خرگوش شمار - زان چار چو بگذری نهنگ آید و مار
/// آنگاه به اسب و گوسفند است حساب - حمدونه و مرغ و سگ و خوک آخر کار
///
/// From https://fa.wikipedia.org/wiki/گاه‌شماری_حیوانی
/// See also https://en.wikipedia.org/wiki/Chinese_zodiac#Signs
enum ChineseZodiac: Int, CaseIterable, Sendable {
    case rat = 0, ox, tiger, rabbit, dragon, snake
    case horse, goat, monkey, rooster, dog, pig

    /// Localization key; the display name comes from the string catalog.
    var titleKey: String {
        switch self {
        case .rat: "animal_year_name_rat"
        case .ox: "animal_year_name_ox"
        case .tiger: "animal_year_name_tiger"
        case .rabbit: "animal_year_name_rabbit"
        case .dragon: "animal_year_name_dragon"
        case .snake: "animal_year_name_snake"
        case .horse: "animal_year_name_horse"
        case .goat: "animal_year_name_goat"
        case .monkey: "animal_year_name_monkey"
        case .rooster: "animal_year_name_rooster"
        case .dog: "animal_year_name_dog"
        case .pig: "animal_year_name_pig"
        }
    }

    private var emoji: String {
        switch self {
        case .rat: "🐀"
        case .ox: "🐂"
        case .tiger: "🐅"
        case .rabbit: "🐇"
        case .dragon: "🐲"
        case .snake: "🐍"
        case .horse: "🐎"
        case .goat: "🐐"
        case .monkey: "🐒"
        case .rooster: "🐓"
        case .dog: "🐕"
        case .pig: "🐖"
        }
    }

    /// Persian usage prefers a different animal for a few of these.
    private var persianSpecificEmoji: String? {
        switch self {
        case .tiger: "🐆"
        case .dragon: "🐊"
        case .goat: "🐑"
        case .rooster: "🐔"
        default: nil
        }
    }

    var persianSpecificTitle: String? {
        switch self {
        case .tiger: "پلنگ"
        case .dragon: "نهنگ"
        case .goat: "گوسفند"
        case .rooster: "مرغ"
        default: nil
        }
    }

    /// The Arabic-derived name as used in Persian texts.
    var arabicNameToUseInPersian: String {
        switch self {
        case .rat: "فاره"
        case .ox: "بقر"
        case .tiger: "نمر"
        case .rabbit: "ارنب"
        case .dragon: "تمساح\n(ثعبان)"
        case .snake: "حیه"
        case .horse: "فرس"
        case .goat: "غنم"
        case .monkey: "حمدونه\n(قرده)"
        case .rooster: "دجاجه"
        case .dog: "کلب"
        case .pig: "خنزیر"
        }
    }

    /// The Turkic era name, e.g. as used in https://rc.majlis.ir/fa/law/show/91137
    var oldEraPersianName: String {
        switch self {
        case .rat: "سیچقان ئیل"
        case .ox: "اود ئیل"
        case .tiger: "بارس ئیل"
        case .rabbit: "تَوِشقان ئیل"
        case .dragon: "لوی ئیل"
        case .snake: "ئیلان ئیل"
        case .horse: "یونت ئیل"
        case .goat: "قُوی ئیل"
        case .monkey: "پیچی ئیل"
        case .rooster: "تُخاقوی ئیل"
        case .dog: "ایت ئیل"
        case .pig: "تُنگوز ئیل"
        }
    }

    func resolveEmoji(isPersian: Bool) -> String {
        (isPersian ? persianSpecificEmoji : nil) ?? emoji
    }

    // https://en.wikipedia.org/wiki/Chinese_zodiac#Compatibility
    func compatibility(with other: ChineseZodiac) -> Compatibility {
        switch (rawValue - other.rawValue + 12) % 12 {
        case 4, 8: return .best
        case 6: return .worse
        default:
            switch (rawValue + other.rawValue) % 12 {
            case 1: return .better
            case 7: return .worst
            default: return .neutral
            }
        }
    }

    enum Compatibility: Sendable { case best, better, neutral, worse, worst }

    // https://en.wikipedia.org/wiki/Chinese_zodiac#Signs
    var yinYang: YinYang { YinYang.allCases[(rawValue + 1) % 2] }

    enum YinYang: CaseIterable, Sendable { case yin, yang }

    var fixedElement: FixedElement { Self.zodiacToElement[rawValue] }

    // https://en.wikipedia.org/wiki/Wuxing_(Chinese_philosophy)
    enum FixedElement: Sendable { case fire, water, wood, metal, earth }

    var trin: Int { (rawValue % 4) + 1 }

    private static let zodiacToElement: [FixedElement] = [
        .water, .earth, .wood, .wood, .earth, .fire,
        .fire, .earth, .metal, .metal, .earth, .water,
    ]

    static func fromPersianCalendar(_ persianDate: PersianDate) -> ChineseZodiac {
        ChineseZodiac(rawValue: Int(floorMod(Double(persianDate.year + 5), 12)))!
    }

    /// From a Chinese-calendar year number, as `Foundation.Calendar(identifier: .chinese)` gives.
    static func fromChineseYear(_ year: Int) -> ChineseZodiac {
        ChineseZodiac(rawValue: (year - 1) % 12)!
    }
}

extension ChineseZodiac {
    /// Localized animal name for the three shipped languages.
    func localizedTitle(_ language: AppLanguage) -> String {
        switch language {
        case .fa: persianSpecificTitle ?? persianNames[rawValue]
        case .ar: arabicNames[rawValue]
        case .en: englishNames[rawValue]
        }
    }

    private var persianNames: [String] {
        ["موش", "گاو", "پلنگ", "خرگوش", "نهنگ", "مار",
         "اسب", "گوسفند", "میمون", "مرغ", "سگ", "خوک"]
    }

    private var arabicNames: [String] {
        ["الفأر", "الثور", "النمر", "الأرنب", "التنين", "الأفعى",
         "الحصان", "الماعز", "القرد", "الديك", "الكلب", "الخنزير"]
    }

    private var englishNames: [String] {
        ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake",
         "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"]
    }
}
