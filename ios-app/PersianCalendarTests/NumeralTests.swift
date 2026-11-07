import XCTest
@testable import PersianCalendar

/// Mirrors `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/NumeralTests.kt`.
final class NumeralTests: XCTestCase {

    func testFormatWorksProperly() {
        XCTAssertEqual("۱۲۳۴۵۶۷۸۹۰", Numeral.persian.format(1_234_567_890))
        XCTAssertEqual("۳٫۱۴", Numeral.persian.format(3.14))
        XCTAssertEqual("௩.௧௪", Numeral.tamil.format(3.14))
        XCTAssertEqual("abc۱۲۳abc", Numeral.persian.format("abc123abc"))
        XCTAssertEqual("abc۱۲۳abc", Numeral.persian.format("abc123abc", isInEdit: true))
        XCTAssertEqual("abc۱۲۳abc", Numeral.persian.format("abc123abc", isInEdit: false))
        XCTAssertEqual("abc123abc", Numeral.arabic.format("abc123abc"))
        XCTAssertEqual("1234567890", Numeral.arabic.format(1_234_567_890))
        XCTAssertEqual("١٢٣٤٥٦٧٨٩٠", Numeral.arabicIndic.format(1_234_567_890))
        XCTAssertEqual("१२३४५६७८९०", Numeral.devanagari.format(1_234_567_890))
        XCTAssertEqual("௧௨௩௪௫௬௭௮௯௦", Numeral.tamil.format(1_234_567_890))
        XCTAssertEqual("１２３４５６７８９０", Numeral.cjk.format(1_234_567_890))
        XCTAssertEqual("௰", Numeral.tamil.format(10))
    }

    func testNumeralParseWorks() {
        XCTAssertEqual(3.14, Numeral.persian.parseDouble("۳٫۱۴"))
        XCTAssertEqual(3.14, Numeral.persian.parseDouble("3.14"))
        XCTAssertNil(Numeral.persian.parseDouble("۱۲۳a"))
        XCTAssertNil(Numeral.persian.parseDouble("a۱۲۳"))
        XCTAssertEqual(12312.0, Numeral.persian.parseDouble("۱۲۳۱۲"))
    }

    func testFormatLongNumberWorksProperly() {
        XCTAssertEqual("۱۲٬۳۱۲٬۳۱۲", Numeral.persian.formatLongNumber(12_312_312))
    }
}
