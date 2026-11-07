import Foundation

/// The left-to-right mark, used to keep numeric runs upright inside RTL text.
let leftToRightMark = "\u{200E}"

/// Numerals written with Arabic letters (abjad), as used in traditional astronomical tables.
///
/// https://en.wikipedia.org/wiki/Abjad_numerals
enum Abjad {
    /// Letter values, iterated from the largest so the greedy conversion works.
    private static let values: [(value: Int, letter: String)] = [
        (1_000_000, "غ غ"), (1000, "غ"),
        (900, "ظ"), (800, "ض"), (700, "ذ"), (600, "خ"), (500, "ث"), (400, "ت"),
        (300, "ش"), (200, "ر"), (100, "ق"),
        (90, "ص"), (80, "ف"), (70, "ع"), (60, "س"), (50, "ن"), (40, "م"), (30, "ل"), (20, "ک"),
        (10, "ی"),
        (9, "ط"), (8, "ح"), (7, "ز"), (6, "و"), (5, "ه"), (4, "د"), (3, "ج"), (2, "ب"), (1, "ا"),
    ]

    static func toAbjad(_ number: Int) -> String {
        // Zero really is written as a Persian digit here: https://imgur.com/a/0eMBO2c
        if number == 0 { return "۰" }
        var remaining = number
        var result = ""
        for entry in values {
            while remaining >= entry.value {
                result += entry.letter
                remaining -= entry.value
            }
        }
        return result
    }
}

/// Format a decimal degree value as `DD°:MM’`, or in abjad numerals.
///
/// Rounds to whole arcminutes first, so 27.996° reads as 28°:00’ rather than 27°:59’.
func formatAngle(_ value: Double, numeral: Numeral = .persian, isAbjad: Bool = false) -> String {
    let rounded = Int((value * 60).rounded())
    let degrees = rounded / 60
    let minutes = rounded - degrees * 60
    if isAbjad { return Abjad.toAbjad(degrees) + " " + Abjad.toAbjad(minutes) }
    return numeral.format(
        leftToRightMark + String(format: "%02d°:%02d’", degrees, minutes) + leftToRightMark)
}
