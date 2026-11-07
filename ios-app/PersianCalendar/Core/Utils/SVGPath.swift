import CoreGraphics
import SwiftUI

/// Parses the subset of SVG path data the bundled map files use.
///
/// `worldmap.txt`, `tectonicplates.txt` and `timezones.txt` come straight from the Android app's
/// `res/raw`. Between them they use only move, line, horizontal, vertical and close — no curves —
/// so this handles those commands and nothing else. Anything unrecognised is skipped rather than
/// throwing, since a partly drawn map is better than a blank one.
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        var current = CGPoint.zero
        /// Where the current subpath began, for `Z`.
        var subpathStart = CGPoint.zero
        var command: Character = "m"
        var hasStarted = false

        var scanner = NumberScanner(data)

        while let next = scanner.peekCommandOrNumber() {
            if let letter = next.command {
                command = letter
                scanner.advanceCommand()
                if letter == "Z" || letter == "z" {
                    path.closeSubpath()
                    current = subpathStart
                    continue
                }
            } else if !hasStarted {
                // Numbers before any command are meaningless.
                scanner.skipNumber()
                continue
            } else {
                // A repeated coordinate run: moveto implicitly continues as lineto.
                if command == "m" { command = "l" }
                if command == "M" { command = "L" }
            }

            let isRelative = command.isLowercase
            switch command.lowercased().first! {
            case "m", "l":
                guard let x = scanner.nextNumber(), let y = scanner.nextNumber() else {
                    return path
                }
                current =
                    isRelative
                    ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                if command == "m" || command == "M" {
                    path.move(to: current)
                    subpathStart = current
                    hasStarted = true
                } else {
                    path.addLine(to: current)
                }
            case "h":
                guard let x = scanner.nextNumber() else { return path }
                current = CGPoint(x: isRelative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
            case "v":
                guard let y = scanner.nextNumber() else { return path }
                current = CGPoint(x: current.x, y: isRelative ? current.y + y : y)
                path.addLine(to: current)
            default:
                scanner.skipNumber()
            }
        }
        return path
    }

    /// Load and parse one of the bundled map path files.
    static func loadResource(_ name: String) -> Path {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return Path() }
        return parse(text)
    }
}

/// A minimal tokenizer for SVG path data.
///
/// SVG allows numbers to run together without separators (`1-2` is two numbers, `.5.5` is two),
/// which is why this is hand-written rather than a `split`.
private struct NumberScanner {
    private let characters: [Character]
    private var index = 0

    init(_ text: String) {
        self.characters = Array(text)
    }

    private mutating func skipSeparators() {
        while index < characters.count,
            characters[index] == " " || characters[index] == "," || characters[index] == "\n"
                || characters[index] == "\r" || characters[index] == "\t"
        {
            index += 1
        }
    }

    struct Token {
        let command: Character?
    }

    mutating func peekCommandOrNumber() -> Token? {
        skipSeparators()
        guard index < characters.count else { return nil }
        let character = characters[index]
        if character.isLetter { return Token(command: character) }
        return Token(command: nil)
    }

    mutating func advanceCommand() {
        index += 1
    }

    mutating func skipNumber() {
        _ = nextNumber()
    }

    mutating func nextNumber() -> CGFloat? {
        skipSeparators()
        guard index < characters.count else { return nil }

        var text = ""
        if characters[index] == "-" || characters[index] == "+" {
            text.append(characters[index])
            index += 1
        }
        var seenDot = false
        while index < characters.count {
            let character = characters[index]
            if character.isNumber {
                text.append(character)
                index += 1
            } else if character == "." && !seenDot {
                seenDot = true
                text.append(character)
                index += 1
            } else {
                break
            }
        }
        guard let value = Double(text) else { return nil }
        return CGFloat(value)
    }
}
