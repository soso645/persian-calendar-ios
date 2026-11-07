import Foundation

/// Numeral systems the app can render digits in.
///
/// https://en.wikipedia.org/wiki/Numeral_system
/// See also https://developer.mozilla.org/en-US/docs/Web/CSS/list-style-type
enum Numeral: String, CaseIterable, Sendable {
    /// ۰۱۲۳۴۵۶۷۸۹ — also called Extended Arabic-Indic
    case persian
    /// 0123456789 — the most common in the world
    case arabic
    /// ٠١٢٣٤٥٦٧٨٩ — used in Central Kurdish for example
    case arabicIndic
    /// ०१२३४५६७८९ — used in Nepali for example
    case devanagari
    /// ௦௧௨௩௪௫௬௭௮௯ — but 10, 100 and 1000 have some complexity
    case tamil
    /// ０１２３４５６７８９ — not used in the UI currently
    case cjk

    static let arabicThousandsSeparator: Character = "٬"
    static let arabicDecimalSeparator: Character = "٫"

    /// The code point of this system's zero digit.
    private var zero: UInt32 {
        switch self {
        case .persian: 0x06F0      // ۰
        case .arabic: 0x0030       // 0
        case .arabicIndic: 0x0660  // ٠
        case .devanagari: 0x0966   // ०
        case .tamil: 0x0BE6        // ௦
        case .cjk: 0xFF10          // ０
        }
    }

    var isArabic: Bool { self == .arabic }
    var isTamil: Bool { self == .tamil }
    var isArabicIndicVariants: Bool { self == .persian || self == .arabicIndic }

    func format(_ number: Int) -> String { format("\(number)") }

    func format(_ number: Double) -> String { format(Self.kotlinDoubleString(number)) }

    func format(_ number: String, isInEdit: Bool = false, skipSeparators: Bool = false) -> String {
        if isArabic { return number }
        if isTamil {
            // Don't format Tamil in edits — too complicated.
            if isInEdit { return number }
            switch number {
            case "10": return "௰"
            case "100": return "௱"
            case "1000": return "௲"
            default: break
            }
        }
        let zero = self.zero
        let decimal = Self.arabicDecimalSeparator.unicodeScalars.first!
        let thousands = Self.arabicThousandsSeparator.unicodeScalars.first!
        return String(String.UnicodeScalarView(number.unicodeScalars.map { scalar in
            if scalar.value >= 0x30 && scalar.value <= 0x39 {
                return UnicodeScalar(zero + (scalar.value - 0x30))!
            }
            if isArabicIndicVariants && !skipSeparators {
                if scalar == "." { return decimal }
                if scalar == "," { return thousands }
            }
            return scalar
        }))
    }

    func parseDouble(_ number: String) -> Double? {
        if isArabic { return Double(number) }
        if isTamil {
            switch number {
            case "௰": return 10
            case "௱": return 100
            case "௲": return 1000
            default: break
            }
        }
        let zero = self.zero
        let mapped = String(String.UnicodeScalarView(number.unicodeScalars.map { scalar in
            if scalar.value >= zero && scalar.value <= zero + 9 {
                return UnicodeScalar(0x30 + (scalar.value - zero))!
            }
            if isArabicIndicVariants {
                if scalar == Self.arabicDecimalSeparator.unicodeScalars.first! { return "." }
                if scalar == Self.arabicThousandsSeparator.unicodeScalars.first! { return "," }
            }
            return scalar
        }))
        return Self.strictDouble(mapped)
    }

    /// Group into thousands with the system's own separator.
    func formatLongNumber(_ value: Int) -> String {
        format(Self.groupThousands(value))
    }

    // MARK: - Helpers

    /// Comma-grouped decimal, matching Kotlin's `"%,d".format(Locale.ENGLISH, value)`.
    private static func groupThousands(_ value: Int) -> String {
        let negative = value < 0
        let digits = Array(String(value.magnitude))
        var grouped: [Character] = []
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { grouped.append(",") }
            grouped.append(digit)
        }
        return (negative ? "-" : "") + String(grouped)
    }

    /// Kotlin's `"$number"` for a Double: an integral value still prints a ".0" tail.
    private static func kotlinDoubleString(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value > 0 ? "Infinity" : "-Infinity" }
        if value == value.rounded() && value.magnitude < 1e15 {
            return String(format: "%.1f", value)
        }
        return "\(value)"
    }

    /// Kotlin's `String.toDoubleOrNull()` rejects trailing junk; Swift's `Double.init` does too,
    /// but it also accepts forms like "0x1p3" and "inf". Restrict to plain decimal notation.
    private static func strictDouble(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789.+-eE")
        guard text.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return Double(text)
    }
}
