import Foundation

/// An error raised while evaluating an expression, standing in for Kotlin's `error(...)`.
struct CalculatorError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

/// A value in the calculator's little language.
///
/// The Kotlin original is a sealed interface; this is an indirect enum, which gives the same
/// closed set of cases with pattern matching.
indirect enum Value: Sendable {
    case null
    case symbol(String)
    /// A number, optionally carrying a unit such as `d`, `h`, `m`, `s` or `deg`.
    case number(Double, unit: String? = nil)
    case function(CalculatorFunction)
    case tuple([Value])
    /// An unevaluated application, kept symbolic when operands aren't all numbers.
    case expression(function: String, arguments: [Value])

    static let timeUnits: [(name: String, seconds: Int)] = [
        ("d", 86400), ("h", 3600), ("m", 60), ("s", 1),
    ]

    static func secondsFactor(of unit: String?) -> Int? {
        timeUnits.first { $0.name == unit }?.seconds
    }
}

/// A callable, with an optional arity check.
struct CalculatorFunction: Sendable {
    let inputCount: Int?
    let body: @Sendable ([Value]) throws -> Value

    func callAsFunction(_ arguments: [Value]) throws -> Value {
        if let inputCount, arguments.count != inputCount {
            throw CalculatorError("Invalid number of inputs")
        }
        return try body(arguments)
    }
}

// MARK: - Rendering

extension Value {
    static func formatNumber(_ value: Double) -> String {
        if value == .infinity { return "Infinity" }
        if value == -.infinity { return "-Infinity" }
        if value.isNaN { return "NaN" }
        if value == value.rounded(.towardZero) {
            // Kotlin's `Double.toInt()` saturates at the 32-bit bounds rather than trapping.
            let clamped = value > Double(Int32.max)
                ? Int(Int32.max)
                : (value < Double(Int32.min) ? Int(Int32.min) : Int(value))
            return String(clamped)
        }
        return javaDoubleToString(value)
    }

    var text: String {
        switch self {
        case .null:
            return ""
        case let .symbol(name):
            return name
        case let .number(value, unit):
            return [Value.formatNumber(value), unit].compactMap { $0 }.joined(separator: " ")
        case .function:
            return "function"
        case let .tuple(values):
            return "(" + values.map(\.text).joined(separator: ", ") + ")"
        case let .expression(function, arguments):
            switch function {
            case "+", "-", "/", "*", "%", "**", "^":
                switch arguments.count {
                case 0: return "0"
                case 1: return arguments[0].text
                default:
                    return "(" + arguments.map(\.text).joined(separator: " \(function) ") + ")"
                }
            default:
                return "\(function)(" + arguments.map(\.text).joined(separator: ", ") + ")"
            }
        }
    }

    /// A seconds-valued number expands into a breakdown by time unit; anything else prints plainly.
    var detailedText: String {
        guard case let .number(value, unit) = self, unit == "s" else { return text }

        var breakdown = ""
        var remainder = value
        for unit in Value.timeUnits {
            let factor = Double(unit.seconds)
            breakdown += "\(Int(floor(remainder / factor)))\(unit.name) "
            remainder = remainder.truncatingRemainder(dividingBy: factor)
        }
        let perUnit = Value.timeUnits
            .map { "\(Value.formatNumber(value / Double($0.seconds))) \($0.name)" }
            .joined(separator: "\n")
        return breakdown.trimmingCharacters(in: .whitespaces) + "\n" + perUnit
    }
}

// MARK: - Arithmetic

extension Value {
    func withUnit(_ unit: String) throws -> Value {
        guard case let .number(value, existingUnit) = self else {
            throw CalculatorError("Not supported number call")
        }
        if existingUnit != nil {
            throw CalculatorError("Trying to add unit to a number already with unit")
        }
        return .number(value, unit: unit)
    }

    func adding(_ other: Value) throws -> Value {
        guard case let .number(lhs, lhsUnit) = self, case let .number(rhs, rhsUnit) = other else {
            return .expression(function: "+", arguments: [self, other])
        }
        if lhsUnit == rhsUnit { return .number(lhs + rhs, unit: lhsUnit) }
        guard let lhsFactor = Value.secondsFactor(of: lhsUnit),
            let rhsFactor = Value.secondsFactor(of: rhsUnit)
        else {
            throw CalculatorError("This addition of units isn't supported")
        }
        return .number(lhs * Double(lhsFactor) + rhs * Double(rhsFactor), unit: "s")
    }

    func subtracting(_ other: Value) throws -> Value {
        guard case .number = self, case .number = other else {
            return .expression(function: "-", arguments: [self, other])
        }
        return try adding(Value.number(-1.0).multiplying(other))
    }

    func multiplying(_ other: Value) throws -> Value {
        guard case let .number(lhs, lhsUnit) = self, case let .number(rhs, rhsUnit) = other else {
            return .expression(function: "*", arguments: [self, other])
        }
        if lhsUnit != nil && rhsUnit != nil {
            throw CalculatorError("Two numbers with unit are multiplied")
        }
        return .number(lhs * rhs, unit: lhsUnit ?? rhsUnit)
    }

    func dividing(_ other: Value) throws -> Value {
        guard case let .number(lhs, lhsUnit) = self, case let .number(rhs, rhsUnit) = other else {
            return .expression(function: "/", arguments: [self, other])
        }
        let resultUnit: String?
        switch (lhsUnit, rhsUnit) {
        case let (l, r) where l == r: resultUnit = nil  // 1m / 2m -> 1
        case let (nil, r?): resultUnit = "1/\(r)"
        case let (l?, nil): resultUnit = l
        case let (l?, r?): resultUnit = "\(l)/\(r)"
        default: resultUnit = nil
        }
        return .number(lhs / rhs, unit: resultUnit)
    }

    func remainder(_ other: Value) throws -> Value {
        guard case let .number(lhs, _) = self, case let .number(rhs, _) = other else {
            return .expression(function: "%", arguments: [self, other])
        }
        return .number(lhs.truncatingRemainder(dividingBy: rhs))
    }

    func power(_ other: Value) throws -> Value {
        guard case let .number(lhs, _) = self, case let .number(rhs, _) = other else {
            return .expression(function: "^", arguments: [self, other])
        }
        return .number(pow(lhs, rhs))
    }
}
