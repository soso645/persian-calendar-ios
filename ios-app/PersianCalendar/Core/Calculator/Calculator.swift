import Foundation

/// Evaluates the calculator's expression language, as used by the Converter screen.
///
/// Mirrors `Eval.kt` and `GrammarVisitor.kt` from the Kotlin library.
public enum Calculator {
    /// Evaluate a program and render its results, one per line.
    static func eval(_ input: String) throws -> String {
        let statements = try Parser.parse(input)
        var evaluator = Evaluator()
        var results: [Value] = []
        for statement in statements {
            let value = try evaluator.run(statement)
            if case .null = value { continue }
            results.append(value)
        }
        if results.count == 1, case .number = results[0] {
            return results[0].detailedText
        }
        return results.map(\.text).joined(separator: "\n")
    }
}

struct Evaluator {
    private var registry: [String: Value]

    init() {
        self.registry = Evaluator.constants
        // `clear` resets the registry back to the built-ins.
        self.registry["clear"] = .function(
            CalculatorFunction(inputCount: 0) { _ in .null })
    }

    mutating func run(_ statement: Statement) throws -> Value {
        switch statement {
        case let .assign(name, node):
            registry[name] = try evaluate(node)
            return .null
        case let .print(node):
            let value = try evaluate(node)
            // A zero-argument function used as a bare expression is invoked.
            if case let .function(function) = value, function.inputCount == 0 {
                if isClear(node) {
                    registry = Evaluator.constants
                    registry["clear"] = value
                    return .null
                }
                return try function([])
            }
            return value
        }
    }

    private func isClear(_ node: Node) -> Bool {
        if case let .symbol(name) = node { return name == "clear" }
        return false
    }

    func evaluate(_ node: Node) throws -> Value {
        switch node {
        case let .number(value):
            return .number(value)

        case let .symbol(name):
            return registry[name] ?? .symbol(name)

        case let .group(elements):
            let values = try elements.map { try evaluate($0) }
            return values.count == 1 ? values[0] : .tuple(values)

        case let .negate(operand):
            return try Value.number(-1.0).multiplying(evaluate(operand))

        case let .binary(op, left, right):
            let lhs = try evaluate(left)
            let rhs = try evaluate(right)
            switch op {
            case "+": return try lhs.adding(rhs)
            case "-": return try lhs.subtracting(rhs)
            case "*": return try lhs.multiplying(rhs)
            case "/": return try lhs.dividing(rhs)
            case "%": return try lhs.remainder(rhs)
            case "^": return try lhs.power(rhs)
            default: throw CalculatorError("Unexpected operator")
            }

        case let .call(atoms):
            return try evaluateCall(atoms)
        }
    }

    /// Juxtaposed atoms are either a units expression (`1d 2h 3m`) or a function application.
    private func evaluateCall(_ atoms: [Node]) throws -> Value {
        let values = try atoms.map { try evaluate($0) }

        // An even run of (number, symbol) pairs is a units expression, summed into seconds.
        if values.count % 2 == 0 {
            var pairs: [(Value, String)] = []
            var isUnits = true
            for index in stride(from: 0, to: values.count, by: 2) {
                guard case .number = values[index], case let .symbol(unit) = values[index + 1]
                else {
                    isUnits = false
                    break
                }
                pairs.append((values[index], unit))
            }
            if isUnits, !pairs.isEmpty {
                var total = try pairs[0].0.withUnit(pairs[0].1)
                for pair in pairs.dropFirst() {
                    total = try total.adding(pair.0.withUnit(pair.1))
                }
                return total
            }
        }

        // Otherwise fold from the right: `f g x` applies `f` to `g x`.
        var accumulator = values[values.count - 1]
        for value in values.dropLast().reversed() {
            switch value {
            case let .function(function):
                if case let .tuple(arguments) = accumulator {
                    accumulator = try function(arguments)
                } else {
                    accumulator = try function([accumulator])
                }
            case .number:
                guard case let .symbol(unit) = accumulator else {
                    throw CalculatorError("Not supported number call")
                }
                accumulator = try value.withUnit(unit)
            default:
                throw CalculatorError("Not supported call")
            }
        }
        return accumulator
    }

    // MARK: - Built-ins

    private static func degOrRadFunction(
        _ name: String, _ action: @escaping @Sendable (Double) -> Double
    ) -> (String, Value) {
        (name, .function(CalculatorFunction(inputCount: 1) { arguments in
            guard case let .number(value, unit) = arguments[0] else {
                return .expression(function: name, arguments: arguments)
            }
            switch unit {
            case "deg": return .number(action(value * .pi / 180))
            case nil: return .number(action(value))
            default: throw CalculatorError("Only degree is acceptable as a unit")
            }
        }))
    }

    private static func unaryFunction(
        _ name: String, _ action: @escaping @Sendable (Double) -> Double
    ) -> (String, Value) {
        (name, .function(CalculatorFunction(inputCount: 1) { arguments in
            guard case let .number(value, unit) = arguments[0] else {
                return .expression(function: name, arguments: arguments)
            }
            guard unit == nil else {
                throw CalculatorError("This unary functions don't accept number with unit.")
            }
            return .number(action(value))
        }))
    }

    private static func binaryFunction(
        _ action: @escaping @Sendable (Double, Double) -> Double
    ) -> Value {
        .function(CalculatorFunction(inputCount: 2) { arguments in
            guard case let .number(x, xUnit) = arguments[0],
                case let .number(y, yUnit) = arguments[1]
            else {
                throw CalculatorError("this binary function only accepts numbers without unit")
            }
            guard xUnit == nil, yUnit == nil else {
                throw CalculatorError("this binary function only accepts numbers without unit")
            }
            return .number(action(x, y))
        })
    }

    static let constants: [String: Value] = {
        var result: [String: Value] = [
            "PI": .number(.pi),
            "E": .number(M_E),
        ]
        for entry in [
            degOrRadFunction("sin", sin), degOrRadFunction("cos", cos),
            degOrRadFunction("tan", tan), degOrRadFunction("cot") { 1 / tan($0) },
            unaryFunction("asin", asin), unaryFunction("acos", acos),
            unaryFunction("atan", atan),
            unaryFunction("sinh", sinh), unaryFunction("cosh", cosh),
            unaryFunction("tanh", tanh), unaryFunction("asinh", asinh),
            unaryFunction("acosh", acosh),
            unaryFunction("sqrt", sqrt), unaryFunction("exp", exp),
            unaryFunction("ln", log), unaryFunction("ceil", ceil),
            unaryFunction("floor", floor),
            unaryFunction("truncate") { $0.rounded(.towardZero) },
            // Kotlin's `round` is ties-to-even, unlike Swift's default ties-away-from-zero.
            unaryFunction("round") { $0.rounded(.toNearestOrEven) },
            unaryFunction("abs", abs),
            unaryFunction("sign") { $0 > 0 ? 1 : ($0 < 0 ? -1 : $0) },
        ] {
            result[entry.0] = entry.1
        }
        result["atan2"] = binaryFunction(atan2)
        result["hypot"] = binaryFunction(hypot)
        // Kotlin's `log(x, base)` takes the value first and the base second.
        result["log"] = binaryFunction { value, base in log(value) / log(base) }
        result["min"] = binaryFunction { Swift.min($0, $1) }
        result["max"] = binaryFunction { Swift.max($0, $1) }
        result["+"] = binaryFunction { $0 + $1 }
        result["-"] = binaryFunction { $0 - $1 }
        result["*"] = binaryFunction { $0 * $1 }
        result["/"] = binaryFunction { $0 / $1 }
        result["%"] = binaryFunction { $0.truncatingRemainder(dividingBy: $1) }
        result["^"] = binaryFunction { pow($0, $1) }
        result["**"] = binaryFunction { pow($0, $1) }
        result["diff"] = .function(CalculatorFunction(inputCount: 2) { arguments in
            guard case let .symbol(name) = arguments[1] else {
                throw CalculatorError("Second argument of diff must be a symbol")
            }
            return try diff(arguments[0], name)
        })
        return result
    }()
}
