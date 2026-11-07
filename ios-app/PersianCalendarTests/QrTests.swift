import XCTest
@testable import PersianCalendar

/// Mirrors `PersianCalendar/src/test/kotlin/com/byagowi/persiancalendar/QrTests.kt`.
final class QrTests: XCTestCase {

    func testBasicQr() {
        let expected = """
█▀▀▀▀▀▀▀█▀▀██▀██▀█▀▀▀██▀▀▀▀▀▀▀█
█ █▀▀▀█ █▄▀█▄▀██▄▄▀ ▀▀█ █▀▀▀█ █
█ █   █ █▄▄▀▄▀█ ▄▀▀█ ██ █   █ █
█ ▀▀▀▀▀ █▀█ ▄ █▀▄▀█ ▄ █ ▀▀▀▀▀ █
█▀█▀▀█▀▀▀▄ ▀██▄█▄ ██▄██▀██▀█▀▀█
███ ▄ █▀█▀▀▀▀▄▀  █▀ ▄▄█ ▄▄█▀▀▄█
█  █▄▀█▀▀  █▀▀█ ▀█▄▄███▄▄█ ▀█▄█
█ ▀▄█▀ ▀▄▄▀▄█ ▀ ▀▄▄▀ ██ █▀▀▀  █
█ ▄█  ▀▀  ▄ ▀ ▄  ▀▄█  ▀█ ▀██ ██
█▀█▀▄█▀▀▀▀█ ▄  ██▄▄▄█▀█▀▀█▀ ▄██
██▀▀██▀▀▀ █▄▀█▀▄█ █▀▀▀ ▀▀▀▀ ███
█▀▀▀▀▀▀▀█ ▄ ██ █ ▄▀ ▀ █▀█  ▄ ▄█
█ █▀▀▀█ █▄▀  ▀█▀▄ ▄ █ ▀▀▀ ▀▀  █
█ █   █ █ █▀▄█ ▄ █▀▄█  █▀▄▄ █ █
█ ▀▀▀▀▀ █▀▀█ █ ▄▄▄ ▀▀ ▄█▄█ █ ██
███████████████████████████████
"""

        let text = "http://www.example.com/ążśźęćńół"
        let result = qr(text)
        XCTAssertFalse(result.isEmpty, "encoder returned no matrix")

        // Render two matrix rows per text row using half-block characters, as the Kotlin test does.
        let rowCount = Int(ceil(Double(result.count) / 2.0)) + 1
        let rendered = (0..<rowCount).map { row -> String in
            let cells = result.indices.map { column -> String in
                let upper = row * 2 - 1
                let lower = row * 2
                let first = !(result.indices.contains(upper) && result[upper][column])
                let second = !(result.indices.contains(lower) && result[lower][column])
                if first { return second ? "█" : "▀" }
                return second ? "▄" : " "
            }.joined()
            return "█" + cells + "█"
        }.joined(separator: "\n")

        XCTAssertEqual(rendered, expected)
    }

    // MARK: - Beyond the Android suite

    func testMatrixSizeMatchesVersion() {
        // Size is version * 4 + 17, so version 1 is 21x21.
        let matrix = qr("HELLO", version: 1)
        XCTAssertEqual(matrix.count, 21)
        XCTAssertTrue(matrix.allSatisfy { $0.count == 21 })
    }

    func testFinderPatternsArePresent() {
        let matrix = qr("HELLO")
        let size = matrix.count
        // Each of the three finder patterns is a 7x7 ring with a 3x3 solid centre.
        for (originRow, originColumn) in [(0, 0), (0, size - 7), (size - 7, 0)] {
            for offset in 0..<7 {
                XCTAssertTrue(matrix[originRow][originColumn + offset], "top edge")
                XCTAssertTrue(matrix[originRow + 6][originColumn + offset], "bottom edge")
                XCTAssertTrue(matrix[originRow + offset][originColumn], "left edge")
                XCTAssertTrue(matrix[originRow + offset][originColumn + 6], "right edge")
            }
            XCTAssertTrue(matrix[originRow + 3][originColumn + 3], "centre")
            XCTAssertFalse(matrix[originRow + 1][originColumn + 1], "inner ring gap")
        }
    }

    func testHigherErrorCorrectionStillEncodes() {
        for level in ErrorCorrectionLevel.allCases {
            let matrix = qr("https://example.com", errorCorrectionLevel: level)
            XCTAssertFalse(matrix.isEmpty, "level \(level) produced nothing")
            XCTAssertEqual(matrix.count, matrix.first?.count)
        }
    }

    func testOverlongInputFallsBackAndEventuallyGivesUp() {
        // Comfortably beyond the 2,953-byte ceiling of version 40 at level L.
        let huge = String(repeating: "a", count: 5000)
        XCTAssertTrue(qr(huge).isEmpty)
    }
}
