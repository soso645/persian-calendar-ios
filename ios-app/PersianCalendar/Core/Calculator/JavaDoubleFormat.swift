import Foundation

/// Format a `Double` the way Java's `Double.toString` does.
///
/// The calculator's output is compared character-for-character against the Kotlin original's, and
/// the two runtimes disagree on how to render a Double:
///
/// | value      | Java / Kotlin           | Swift                     |
/// |------------|-------------------------|---------------------------|
/// | 2.3148e-5  | `2.3148148148148147E-5` | `2.3148148148148147e-05`  |
/// | 5.5555e-4  | `5.555555555555556E-4`  | `0.0005555555555555556`   |
///
/// Both pick the same shortest round-tripping digits, so this reformats Swift's rendering into
/// Java's layout rather than reimplementing the digit generation.
func javaDoubleToString(_ value: Double) -> String {
    if value.isNaN { return "NaN" }
    if value.isInfinite { return value > 0 ? "Infinity" : "-Infinity" }
    if value == 0 { return value.sign == .minus ? "-0.0" : "0.0" }

    let negative = value < 0
    let text = String(abs(value))

    // Split Swift's rendering into a digit string and a power of ten.
    let parts = text.lowercased().split(separator: "e", maxSplits: 1)
    let mantissa = String(parts[0])
    let exponent = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

    let mantissaParts = mantissa.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let integerPart = String(mantissaParts[0])
    let fractionPart = mantissaParts.count > 1 ? String(mantissaParts[1]) : ""

    var digits = Array(integerPart + fractionPart)
    // `value == digits as an integer * 10^power`
    var power = exponent - fractionPart.count

    // Normalize away leading and trailing zeros.
    while digits.count > 1 && digits.first == "0" { digits.removeFirst() }
    while digits.count > 1 && digits.last == "0" {
        digits.removeLast()
        power += 1
    }
    if digits == ["0"] { return negative ? "-0.0" : "0.0" }

    // Position of the decimal point relative to the start of `digits`.
    let pointPosition = digits.count + power
    let sign = negative ? "-" : ""

    // Java switches to scientific notation outside [1e-3, 1e7).
    if pointPosition >= -2 && pointPosition <= 7 {
        if pointPosition <= 0 {
            return sign + "0." + String(repeating: "0", count: -pointPosition) + String(digits)
        }
        if pointPosition >= digits.count {
            return sign + String(digits)
                + String(repeating: "0", count: pointPosition - digits.count) + ".0"
        }
        return sign + String(digits[0..<pointPosition]) + "." + String(digits[pointPosition...])
    }

    let fraction = digits.count > 1 ? String(digits[1...]) : "0"
    return sign + String(digits[0]) + "." + fraction + "E" + String(pointPosition - 1)
}
