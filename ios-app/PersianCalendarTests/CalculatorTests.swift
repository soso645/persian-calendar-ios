import XCTest
@testable import PersianCalendar

/// Mirrors `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/CalculatorTests.kt`.
final class CalculatorTests: XCTestCase {

    func testTimeCalculator() throws {
        // Based on calculator.net's time calculator
        XCTAssertEqual(
            try Calculator.eval("2s"),
            """
            0d 0h 0m 2s
            2.3148148148148147E-5 d
            5.555555555555556E-4 h
            0.03333333333333333 m
            2 s
            """)

        let expected = """
            2d 9h 29m 19s
            2.3953587962962963 d
            57.48861111111111 h
            3449.3166666666666 m
            206959 s
            """
        XCTAssertEqual(
            try Calculator.eval("1d + 2h + 3m + 4s + 4h + 5s - 2030s + 28h"), expected)
        XCTAssertEqual(
            try Calculator.eval("1d 2h 3m 4s + 4h 5s - 2030s + 28h"), expected)
    }

    func testErrors() {
        for input in ["5+ 5 5 6 +  7", "7 / 5 * ((2 + 2) / (((5 -7) + 2) * 2)"] {
            XCTAssertThrowsError(try Calculator.eval(input), "should fail: \(input)")
        }
    }

    // MARK: - Beyond the Android suite

    /// The Java/Kotlin `Double.toString` layout the expected output above depends on.
    func testJavaDoubleFormatting() {
        XCTAssertEqual(javaDoubleToString(2.3148148148148147e-5), "2.3148148148148147E-5")
        XCTAssertEqual(javaDoubleToString(5.555555555555556e-4), "5.555555555555556E-4")
        XCTAssertEqual(javaDoubleToString(0.03333333333333333), "0.03333333333333333")
        XCTAssertEqual(javaDoubleToString(3449.3166666666666), "3449.3166666666666")
        XCTAssertEqual(javaDoubleToString(1.0), "1.0")
        XCTAssertEqual(javaDoubleToString(0.001), "0.001")
        XCTAssertEqual(javaDoubleToString(0.0001), "1.0E-4")
        XCTAssertEqual(javaDoubleToString(9_999_999.0), "9999999.0")
        XCTAssertEqual(javaDoubleToString(1e7), "1.0E7")
        XCTAssertEqual(javaDoubleToString(-2.5), "-2.5")
        XCTAssertEqual(javaDoubleToString(0), "0.0")
        XCTAssertEqual(javaDoubleToString(.nan), "NaN")
        XCTAssertEqual(javaDoubleToString(.infinity), "Infinity")
    }

    func testArithmeticAndPrecedence() throws {
        XCTAssertEqual(try Calculator.eval("1 + 2 * 3"), "7")
        XCTAssertEqual(try Calculator.eval("(1 + 2) * 3"), "9")
        // Exponentiation is right associative: 2^(3^2) = 512, not (2^3)^2 = 64.
        XCTAssertEqual(try Calculator.eval("2 ^ 3 ^ 2"), "512")
        XCTAssertEqual(try Calculator.eval("2 ** 3"), "8")
        XCTAssertEqual(try Calculator.eval("-3 + 1"), "-2")
        XCTAssertEqual(try Calculator.eval("7 % 3"), "1")
        XCTAssertEqual(try Calculator.eval("sqrt(16)"), "4")
        XCTAssertEqual(try Calculator.eval("max(3, 9)"), "9")
        XCTAssertEqual(try Calculator.eval("sin(0)"), "0")
    }

    func testAssignmentAndSymbols() throws {
        XCTAssertEqual(try Calculator.eval("x = 5; x * 2"), "10")
        // An unbound symbol stays symbolic rather than failing.
        XCTAssertEqual(try Calculator.eval("y + 1"), "(y + 1)")
    }

    /// The original applies the chain rule without simplifying the result — it carries explicit
    /// TODOs about that — so `* 1` and `^ 1` factors are expected to survive. These assertions
    /// pin the unsimplified shape the Kotlin implementation produces.
    func testDifferentiation() throws {
        XCTAssertEqual(try Calculator.eval("diff(x ^ 2, x)"), "((2 * (x ^ 1)) * 1)")
        XCTAssertEqual(try Calculator.eval("diff(sin(x), x)"), "(cos(x) * 1)")
        XCTAssertEqual(try Calculator.eval("diff(5, x)"), "0")
        XCTAssertEqual(try Calculator.eval("diff(x, x)"), "1")
        // A derivative with respect to an unrelated symbol is zero.
        XCTAssertEqual(try Calculator.eval("diff(y, x)"), "0")
    }

    func testComments() throws {
        XCTAssertEqual(try Calculator.eval("# a comment\n2 + 2"), "4")
        XCTAssertEqual(try Calculator.eval("// another\n3 + 3"), "6")
    }
}
