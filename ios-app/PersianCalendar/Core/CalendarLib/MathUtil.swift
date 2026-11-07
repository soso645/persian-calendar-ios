import Foundation

/// Kotlin's `Int.floorDiv` — division rounding towards negative infinity.
/// Swift's `/` truncates towards zero, so this cannot be spelled with `/` alone.
@inline(__always)
func floorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    let r = a % b
    return (r != 0 && ((r < 0) != (b < 0))) ? q - 1 : q
}

/// Kotlin's `Double.mod(other)` — remainder carrying the sign of the *divisor*.
/// Distinct from Swift's `truncatingRemainder`, which carries the sign of the dividend.
@inline(__always)
func floorMod(_ x: Double, _ y: Double) -> Double {
    let r = x.truncatingRemainder(dividingBy: y)
    return (r != 0 && (r < 0) != (y < 0)) ? r + y : r
}

/// Kotlin's `kotlin.math.sign(Double)`.
@inline(__always)
func signOf(_ x: Double) -> Double {
    if x.isNaN { return Double.nan }
    if x > 0 { return 1.0 }
    if x < 0 { return -1.0 }
    return 0.0
}

/// Kotlin's `kotlin.math.round` maps to `Math.rint` — ties to *even*, not ties away from zero.
/// Swift's plain `.rounded()` is ties-away-from-zero, so the rule is spelled out here.
@inline(__always)
func rint(_ x: Double) -> Double { x.rounded(.toNearestOrEven) }

@inline(__always)
func toRadians(_ degrees: Double) -> Double { degrees * .pi / 180.0 }

@inline(__always)
func sinOfDegree(_ degree: Double) -> Double { sin(toRadians(degree)) }

@inline(__always)
func cosOfDegree(_ degree: Double) -> Double { cos(toRadians(degree)) }

@inline(__always)
func tanOfDegree(_ degree: Double) -> Double { tan(toRadians(degree)) }
