import Foundation

/// Symbolic differentiation of `f` with respect to `symbol`.
///
/// Mirrors `Differentiation.kt`. The chain rule is spelled out per function, as in the original.
func diff(_ f: Value, _ symbol: String) throws -> Value {
    switch f {
    case .number:
        return .number(0.0)

    case let .symbol(name):
        return .number(name == symbol ? 1.0 : 0.0)

    case let .expression(function, arguments):
        switch function {
        case "+", "-":
            let derivatives = try arguments.map { try diff($0, symbol) }
            return .expression(
                function: function, arguments: derivatives.filter { !$0.isZeroNumber })

        case "*":
            guard arguments.count == 2 else {
                throw CalculatorError("Only multiplication of two operands is supported")
            }
            let terms = [
                try arguments[0].multiplying(diff(arguments[1], symbol)),
                try arguments[1].multiplying(diff(arguments[0], symbol)),
            ]
            return .expression(function: "+", arguments: terms.filter(keepsTerm))

        case "/":
            guard arguments.count == 2 else {
                throw CalculatorError("Only division of two operands is supported")
            }
            let terms = [
                try arguments[0].multiplying(diff(arguments[1], symbol)),
                try arguments[1].multiplying(diff(arguments[0], symbol)),
            ]
            let numerator = Value.expression(function: "-", arguments: terms.filter(keepsTerm))
            return try numerator.dividing(arguments[1].power(.number(2.0)))

        case "^":
            guard arguments.count == 2 else {
                throw CalculatorError("Only exponential of two operands is supported")
            }
            guard case let .number(exponentValue, _) = arguments[1] else {
                throw CalculatorError("Only constant exponents are supported")
            }
            let lowered = try arguments[0].power(.number(exponentValue - 1))
            return try arguments[1].multiplying(lowered).multiplying(diff(arguments[0], symbol))

        case "sqrt":
            guard arguments.count == 1 else {
                throw CalculatorError("Sqrt should have one argument")
            }
            let numerator = try Value.number(0.5).multiplying(diff(arguments[0], symbol))
            return try numerator.dividing(.expression(function: "sqrt", arguments: arguments))

        case "ln":
            guard arguments.count == 1 else { throw CalculatorError("ln should have one argument") }
            return try diff(arguments[0], symbol).dividing(arguments[0])

        case "exp":
            guard arguments.count == 1 else {
                throw CalculatorError("exp should have one argument")
            }
            return try Value.expression(function: "exp", arguments: arguments)
                .multiplying(diff(arguments[0], symbol))

        case "sin":
            guard arguments.count == 1 else {
                throw CalculatorError("sin should have one argument")
            }
            return try Value.expression(function: "cos", arguments: arguments)
                .multiplying(diff(arguments[0], symbol))

        case "cos":
            guard arguments.count == 1 else {
                throw CalculatorError("cos should have one argument")
            }
            return try Value.number(-1.0)
                .multiplying(.expression(function: "sin", arguments: arguments))
                .multiplying(diff(arguments[0], symbol))

        case "tan":
            guard arguments.count == 1 else {
                throw CalculatorError("tan should have one argument")
            }
            let tanSquared = try Value.expression(function: "tan", arguments: arguments)
                .power(.number(2.0))
            return try Value.number(1.0).adding(tanSquared)
                .multiplying(diff(arguments[0], symbol))

        default:
            throw CalculatorError("Not supported function to differentiate \(f.text)")
        }

    default:
        return .expression(function: "diff", arguments: [f, .symbol(symbol)])
    }
}

/// Drop product/quotient terms that are identically zero.
private func keepsTerm(_ argument: Value) -> Bool {
    guard case let .expression(_, arguments) = argument else { return true }
    return arguments.allSatisfy { !$0.isZeroNumber }
}

extension Value {
    fileprivate var isZeroNumber: Bool {
        if case let .number(value, _) = self { return value == 0 }
        return false
    }
}
