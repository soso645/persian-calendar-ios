import SwiftUI
import XCTest
@testable import PersianCalendar

/// The SVG path parser and the day/night terminator. No Android counterpart — the Kotlin map is
/// covered only by an instrumented screenshot test.
final class MapTests: XCTestCase {

    // MARK: - SVG parsing

    func testParsesAbsoluteAndRelativeLines() {
        // A 10x10 square drawn with a mix of absolute and relative commands.
        let path = SVGPath.parse("M0 0 H10 V10 H0 Z")
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.boundingRect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.minY, 0, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.width, 10, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.height, 10, accuracy: 0.001)
    }

    func testRelativeCommandsAccumulate() {
        let path = SVGPath.parse("m5 5 h10 v10 h-10 z")
        XCTAssertEqual(path.boundingRect.minX, 5, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.maxX, 15, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.maxY, 15, accuracy: 0.001)
    }

    /// SVG lets numbers run together without separators, which is why the scanner is hand-written.
    func testNumbersRunTogetherWithoutSeparators() {
        // "1-2" is two numbers; ".5.5" is 0.5 then 0.5.
        let path = SVGPath.parse("M0 0 l10-5")
        XCTAssertEqual(path.boundingRect.maxX, 10, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.minY, -5, accuracy: 0.001)
    }

    /// A moveto followed by extra coordinate pairs continues as a lineto, per the SVG spec.
    func testImplicitLinetoAfterMoveto() {
        let path = SVGPath.parse("M0 0 10 0 10 10")
        XCTAssertEqual(path.boundingRect.width, 10, accuracy: 0.001)
        XCTAssertEqual(path.boundingRect.height, 10, accuracy: 0.001)
    }

    func testMalformedInputDoesNotTrap() {
        XCTAssertTrue(SVGPath.parse("").isEmpty)
        XCTAssertTrue(SVGPath.parse("garbage").isEmpty)
        // A truncated command must return what it parsed rather than crashing.
        _ = SVGPath.parse("M0 0 L10")
        _ = SVGPath.parse("M0 0 C1 2 3")
    }

    // MARK: - Bundled map data

    /// Each map file must parse and land inside the 360x180-degree grid scaled by 16.
    func testBundledMapsParseWithinTheExpectedBounds() {
        for name in ["worldmap", "tectonicplates", "timezones"] {
            let path = SVGPath.loadResource(name)
            XCTAssertFalse(path.isEmpty, "\(name) produced an empty path")
            let bounds = path.boundingRect
            XCTAssertGreaterThan(bounds.width, 1000, "\(name) is suspiciously narrow")
            // The source data overshoots the frame by a couple of units in places — Antarctica
            // runs 2 units (0.125 degrees) past the southern edge — so allow a small margin.
            // `MapCanvas` clips to the exact frame, so the overshoot never reaches the screen.
            let margin: CGFloat = 8
            XCTAssertLessThanOrEqual(
                bounds.maxX, 360 * 16 + margin, "\(name) overflows to the east")
            XCTAssertLessThanOrEqual(
                bounds.maxY, 180 * 16 + margin, "\(name) overflows to the south")
            XCTAssertGreaterThanOrEqual(bounds.minX, -margin, "\(name) overflows to the west")
            XCTAssertGreaterThanOrEqual(bounds.minY, -margin, "\(name) overflows to the north")
        }
    }

    // MARK: - Globe projection

    /// The projection centre lands in the middle of the view, and its antipode is culled.
    func testOrthographicProjectionCentreAndAntipode() {
        let projection = OrthographicProjection(
            centerLatitude: 35, centerLongitude: 51,
            radius: 100, center: CGPoint(x: 150, y: 150))

        let centre = projection.project(.init(latitude: 35, longitude: 51))
        XCTAssertEqual(centre?.x ?? 0, 150, accuracy: 0.001)
        XCTAssertEqual(centre?.y ?? 0, 150, accuracy: 0.001)

        // The far side of the sphere must not be drawn.
        XCTAssertNil(projection.project(.init(latitude: -35, longitude: -129)))
    }

    /// North of the centre projects upwards on screen, east projects to the right.
    func testOrthographicProjectionOrientation() {
        let projection = OrthographicProjection(
            centerLatitude: 0, centerLongitude: 0,
            radius: 100, center: CGPoint(x: 100, y: 100))

        let north = try? XCTUnwrap(projection.project(.init(latitude: 30, longitude: 0)))
        XCTAssertLessThan(north?.y ?? 999, 100, "north should be above centre")
        XCTAssertEqual(north?.x ?? 0, 100, accuracy: 0.001)

        let east = try? XCTUnwrap(projection.project(.init(latitude: 0, longitude: 30)))
        XCTAssertGreaterThan(east?.x ?? 0, 100, "east should be right of centre")
        XCTAssertEqual(east?.y ?? 0, 100, accuracy: 0.001)
    }

    /// Every projected point stays inside the drawn circle.
    func testProjectedPointsStayWithinTheDisc() {
        let radius: CGFloat = 120
        let centre = CGPoint(x: 200, y: 200)
        let projection = OrthographicProjection(
            centerLatitude: 20, centerLongitude: 45, radius: radius, center: centre)

        for latitude in stride(from: -90.0, through: 90.0, by: 10) {
            for longitude in stride(from: -180.0, through: 180.0, by: 10) {
                guard
                    let point = projection.project(
                        .init(latitude: latitude, longitude: longitude))
                else { continue }
                let distance = hypot(point.x - centre.x, point.y - centre.y)
                XCTAssertLessThanOrEqual(
                    distance, radius + 0.001,
                    "point at \(latitude),\(longitude) fell outside the globe")
            }
        }
    }

    /// The coastline geometry must survive the round trip out of the equirectangular path.
    func testGlobeCoastlinesAreWithinGeographicBounds() {
        let lines = GlobeGeometry.coastlines
        XCTAssertGreaterThan(lines.count, 100, "too few coastline subpaths")
        for line in lines {
            XCTAssertGreaterThan(line.count, 1, "a subpath should have at least two points")
            for point in line {
                XCTAssertTrue(
                    (-91.0...91.0).contains(point.latitude),
                    "latitude out of range: \(point.latitude)")
                XCTAssertTrue(
                    (-181.0...181.0).contains(point.longitude),
                    "longitude out of range: \(point.longitude)")
            }
        }
    }

    // MARK: - Day/night

    /// At an equinox the subsolar point sits on the equator, and at a solstice near a tropic.
    func testSubsolarLatitudeTracksTheSeason() {
        let equinox = seasons(2024).marchEquinox
        XCTAssertEqual(Terminator.subsolarPoint(equinox).latitude, 0, accuracy: 0.5)

        let juneSolstice = seasons(2024).juneSolstice
        XCTAssertEqual(Terminator.subsolarPoint(juneSolstice).latitude, 23.44, accuracy: 0.2)

        let decemberSolstice = seasons(2024).decemberSolstice
        XCTAssertEqual(Terminator.subsolarPoint(decemberSolstice).latitude, -23.44, accuracy: 0.2)
    }

    /// The Sun is overhead at the subsolar point and below the horizon at its antipode.
    func testDaylightAtAndOppositeTheSubsolarPoint() {
        let time = AstroTime(year: 2024, month: 8, day: 14, hour: 12, minute: 0, second: 0)
        let subsolar = Terminator.subsolarPoint(time)

        XCTAssertTrue(
            Terminator.isDaylight(
                latitude: subsolar.latitude, longitude: subsolar.longitude, subsolar: subsolar))
        XCTAssertFalse(
            Terminator.isDaylight(
                latitude: -subsolar.latitude,
                longitude: floorMod(subsolar.longitude + 180 + 180, 360) - 180,
                subsolar: subsolar))
    }

    /// Points exactly on the terminator are at the day/night boundary, so daylight must flip
    /// across it.
    func testTerminatorSeparatesDayFromNight() {
        let time = AstroTime(year: 2024, month: 8, day: 14, hour: 12, minute: 0, second: 0)
        let subsolar = Terminator.subsolarPoint(time)

        for longitude in stride(from: -180.0, through: 180.0, by: 30.0) {
            let latitude = Terminator.terminatorLatitude(
                longitude: longitude, subsolar: subsolar)
            let above = Terminator.isDaylight(
                latitude: min(latitude + 2, 90), longitude: longitude, subsolar: subsolar)
            let below = Terminator.isDaylight(
                latitude: max(latitude - 2, -90), longitude: longitude, subsolar: subsolar)
            XCTAssertNotEqual(
                above, below,
                "daylight did not flip across the terminator at longitude \(longitude)")
        }
    }

    /// In northern summer the Arctic has polar day, so the pole must be lit.
    func testPolarDayInNorthernSummer() {
        let time = seasons(2024).juneSolstice
        let subsolar = Terminator.subsolarPoint(time)
        XCTAssertTrue(
            Terminator.isDaylight(latitude: 89, longitude: 0, subsolar: subsolar),
            "North Pole should be lit at the June solstice")
        XCTAssertFalse(
            Terminator.isDaylight(latitude: -89, longitude: 0, subsolar: subsolar),
            "South Pole should be dark at the June solstice")
    }
}
