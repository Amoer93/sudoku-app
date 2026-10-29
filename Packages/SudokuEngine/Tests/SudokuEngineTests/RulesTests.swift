import Foundation
import SudokuEngine
import XCTest

final class RulesTests: XCTestCase {
    func testPresetsMatchTheThreeStandardGames() {
        XCTAssertEqual(Rules.supportedSizes, [4, 5, 9])

        XCTAssertEqual(Rules.fourByFour.size, 4)
        XCTAssertEqual(Rules.fourByFour.boxRows, 2)
        XCTAssertEqual(Rules.fourByFour.boxCols, 2)
        XCTAssertTrue(Rules.fourByFour.hasBoxes)
        XCTAssertEqual(Rules.fourByFour.cellCount, 16)

        XCTAssertEqual(Rules.fiveByFive.size, 5)
        XCTAssertNil(Rules.fiveByFive.boxRows)
        XCTAssertNil(Rules.fiveByFive.boxCols)
        XCTAssertFalse(Rules.fiveByFive.hasBoxes)
        XCTAssertEqual(Rules.fiveByFive.cellCount, 25)

        XCTAssertEqual(Rules.nineByNine.size, 9)
        XCTAssertEqual(Rules.nineByNine.boxRows, 3)
        XCTAssertEqual(Rules.nineByNine.boxCols, 3)
        XCTAssertTrue(Rules.nineByNine.hasBoxes)
        XCTAssertEqual(Rules.nineByNine.cellCount, 81)
    }

    func testThrowingInitAcceptsOnlyStandardBoxes() throws {
        XCTAssertEqual(try Rules(size: 4, boxRows: 2, boxCols: 2), .fourByFour)
        XCTAssertEqual(try Rules(size: 5, boxRows: nil, boxCols: nil), .fiveByFive)
        XCTAssertEqual(try Rules(size: 9, boxRows: 3, boxCols: 3), .nineByNine)
    }

    func testThrowingInitRejectsUnsupportedSize() {
        XCTAssertThrowsError(try Rules(size: 6, boxRows: 2, boxCols: 3)) { error in
            XCTAssertEqual(error as? Rules.ValidationError, .unsupportedSize(6))
        }
    }

    func testThrowingInitRejectsNonstandardBoxes() {
        assertInvalidBoxes(size: 4, boxRows: nil, boxCols: nil)
        assertInvalidBoxes(size: 4, boxRows: 1, boxCols: 4)
        assertInvalidBoxes(size: 4, boxRows: 2, boxCols: nil)
        assertInvalidBoxes(size: 5, boxRows: 1, boxCols: 5)
        assertInvalidBoxes(size: 9, boxRows: nil, boxCols: nil)
        assertInvalidBoxes(size: 9, boxRows: 9, boxCols: 1)
    }

    func testCodableRoundTrip() throws {
        for rules in [Rules.fourByFour, .fiveByFive, .nineByNine] {
            let data = try JSONEncoder().encode(rules)
            let decoded = try JSONDecoder().decode(Rules.self, from: data)
            XCTAssertEqual(decoded, rules)
        }
    }

    func testFiveByFiveEncodesNullBoxesAndAcceptsMissingKeys() throws {
        let data = try JSONEncoder().encode(Rules.fiveByFive)
        let raw = try JSONSerialization.jsonObject(with: data)
        let object = try XCTUnwrap(raw as? [String: Any])
        XCTAssertEqual(object["size"] as? Int, 5)
        XCTAssertTrue(object["boxRows"] is NSNull)
        XCTAssertTrue(object["boxCols"] is NSNull)

        let decoded = try JSONDecoder().decode(Rules.self, from: Data(#"{"size":5}"#.utf8))
        XCTAssertEqual(decoded, .fiveByFive)
    }

    func testDecodingRejectsUnsupportedRules() {
        let data = Data(#"{"size":6,"boxRows":2,"boxCols":3}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Rules.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    private func assertInvalidBoxes(size: Int, boxRows: Int?, boxCols: Int?) {
        XCTAssertThrowsError(try Rules(size: size, boxRows: boxRows, boxCols: boxCols)) { error in
            XCTAssertEqual(
                error as? Rules.ValidationError,
                .invalidBoxDimensions(size: size, boxRows: boxRows, boxCols: boxCols)
            )
        }
    }
}
