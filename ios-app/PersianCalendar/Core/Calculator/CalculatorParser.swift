import Foundation

// A hand-written lexer and recursive-descent parser for the calculator's grammar.
//
// The Kotlin library generates its parser from an ANTLR grammar at build time. ANTLR has no Swift
// target here, so the grammar below is transcribed by hand from `Grammar.g4`:
//
//     program                  : statement*
//     statement                : SYMBOL '=' expression (DELIM | EOF)
//                              | COMMENT
//                              | expression (DELIM | EOF)
//                              | DELIM
//     expression               : additiveExpression
//     additiveExpression       : multiplicativeExpression (('+' | '-') multiplicativeExpression)*
//     multiplicativeExpression : exponentialExpression (('*' | '/' | '%') exponentialExpression)*
//     exponentialExpression    : signedAtom (('^' | '**') signedAtom)*      // right associative
//     signedAtom               : ('-' | '+') signedAtom | call | atom
//     call                     : atom+
//     atom                     : '(' (expression (',' expression)*)? ')' | NUMBER | SYMBOL

// MARK: - Tokens

enum Token: Equatable {
    case number(Double)
    case symbol(String)
    case op(String)
    case openParen
    case closeParen
    case comma
    case assign
    case delimiter
}

enum Lexer {
    static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        let characters = Array(input)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == " " || character == "\t" {
                index += 1
                continue
            }

            if character == "\r" {
                index += 1
                if index < characters.count && characters[index] == "\n" { index += 1 }
                tokens.append(.delimiter)
                continue
            }
            if character == "\n" || character == ";" {
                index += 1
                tokens.append(.delimiter)
                continue
            }

            // Comments run to the end of the line.
            if character == "#"
                || (character == "/" && index + 1 < characters.count && characters[index + 1] == "/")
            {
                while index < characters.count && characters[index] != "\n" { index += 1 }
                continue
            }

            if character.isNumber {
                var text = ""
                while index < characters.count && characters[index].isNumber {
                    text.append(characters[index])
                    index += 1
                }
                if index < characters.count && characters[index] == "."
                    && index + 1 < characters.count && characters[index + 1].isNumber
                {
                    text.append(".")
                    index += 1
                    while index < characters.count && characters[index].isNumber {
                        text.append(characters[index])
                        index += 1
                    }
                }
                if index < characters.count && (characters[index] == "e" || characters[index] == "E")
                {
                    // Only consume the exponent if it is well formed, so `2e` lexes as `2` then `e`.
                    var lookahead = index + 1
                    var exponent = String(characters[index])
                    if lookahead < characters.count
                        && (characters[lookahead] == "+" || characters[lookahead] == "-")
                    {
                        exponent.append(characters[lookahead])
                        lookahead += 1
                    }
                    if lookahead < characters.count && characters[lookahead].isNumber {
                        while lookahead < characters.count && characters[lookahead].isNumber {
                            exponent.append(characters[lookahead])
                            lookahead += 1
                        }
                        text += exponent
                        index = lookahead
                    }
                }
                guard let value = Double(text) else {
                    throw CalculatorError("Invalid number \(text)")
                }
                tokens.append(.number(value))
                continue
            }

            if character.isLetter || character == "_" {
                var text = ""
                while index < characters.count
                    && (characters[index].isLetter || characters[index] == "_")
                {
                    text.append(characters[index])
                    index += 1
                }
                tokens.append(.symbol(text))
                continue
            }

            switch character {
            case "(": tokens.append(.openParen); index += 1
            case ")": tokens.append(.closeParen); index += 1
            case ",": tokens.append(.comma); index += 1
            case "=": tokens.append(.assign); index += 1
            case "+", "-", "%", "^": tokens.append(.op(String(character))); index += 1
            case "/": tokens.append(.op("/")); index += 1
            case "*":
                if index + 1 < characters.count && characters[index + 1] == "*" {
                    tokens.append(.op("**"))
                    index += 2
                } else {
                    tokens.append(.op("*"))
                    index += 1
                }
            default:
                throw CalculatorError("Unexpected character '\(character)'")
            }
        }
        return tokens
    }
}

// MARK: - Syntax tree

indirect enum Node {
    case number(Double)
    case symbol(String)
    /// A parenthesized list; one element behaves as simple grouping.
    case group([Node])
    /// Juxtaposed atoms — either a function application or a units expression.
    case call([Node])
    case negate(Node)
    case binary(String, Node, Node)
}

enum Statement {
    case assign(String, Node)
    case print(Node)
}

struct Parser {
    private let tokens: [Token]
    private var index = 0

    init(_ tokens: [Token]) { self.tokens = tokens }

    private var current: Token? { index < tokens.count ? tokens[index] : nil }

    private mutating func advance() { index += 1 }

    private mutating func match(_ token: Token) -> Bool {
        if current == token {
            advance()
            return true
        }
        return false
    }

    static func parse(_ input: String) throws -> [Statement] {
        var parser = Parser(try Lexer.tokenize(input))
        return try parser.parseProgram()
    }

    mutating func parseProgram() throws -> [Statement] {
        var statements: [Statement] = []
        while current != nil {
            if match(.delimiter) { continue }
            statements.append(try parseStatement())
            if current != nil && !match(.delimiter) {
                throw CalculatorError("Expected end of statement, found \(current!)")
            }
        }
        return statements
    }

    private mutating func parseStatement() throws -> Statement {
        // `SYMBOL = expression` — needs one token of lookahead to tell an assignment from a call.
        if case let .symbol(name) = current, index + 1 < tokens.count, tokens[index + 1] == .assign {
            advance()
            advance()
            return .assign(name, try parseExpression())
        }
        return .print(try parseExpression())
    }

    private mutating func parseExpression() throws -> Node {
        try parseAdditive()
    }

    private mutating func parseAdditive() throws -> Node {
        var left = try parseMultiplicative()
        while case let .op(symbol) = current, symbol == "+" || symbol == "-" {
            advance()
            left = .binary(symbol, left, try parseMultiplicative())
        }
        return left
    }

    private mutating func parseMultiplicative() throws -> Node {
        var left = try parseExponential()
        while case let .op(symbol) = current, symbol == "*" || symbol == "/" || symbol == "%" {
            advance()
            left = .binary(symbol, left, try parseExponential())
        }
        return left
    }

    /// Right associative, matching the Kotlin visitor's `reduceRight`.
    private mutating func parseExponential() throws -> Node {
        let left = try parseSignedAtom()
        if case let .op(symbol) = current, symbol == "^" || symbol == "**" {
            advance()
            return .binary("^", left, try parseExponential())
        }
        return left
    }

    private mutating func parseSignedAtom() throws -> Node {
        if case let .op(symbol) = current, symbol == "-" || symbol == "+" {
            advance()
            let operand = try parseSignedAtom()
            return symbol == "-" ? .negate(operand) : operand
        }
        return try parseCall()
    }

    /// One or more juxtaposed atoms.
    private mutating func parseCall() throws -> Node {
        var atoms = [try parseAtom()]
        while startsAtom { atoms.append(try parseAtom()) }
        return atoms.count == 1 ? atoms[0] : .call(atoms)
    }

    private var startsAtom: Bool {
        switch current {
        case .number, .symbol, .openParen: true
        default: false
        }
    }

    private mutating func parseAtom() throws -> Node {
        switch current {
        case let .number(value):
            advance()
            return .number(value)
        case let .symbol(name):
            advance()
            return .symbol(name)
        case .openParen:
            advance()
            if match(.closeParen) { return .group([]) }
            var elements = [try parseExpression()]
            while match(.comma) { elements.append(try parseExpression()) }
            guard match(.closeParen) else { throw CalculatorError("Expected ')'") }
            return .group(elements)
        case nil:
            throw CalculatorError("Unexpected end of input")
        case let other?:
            throw CalculatorError("Unexpected token \(other)")
        }
    }
}
