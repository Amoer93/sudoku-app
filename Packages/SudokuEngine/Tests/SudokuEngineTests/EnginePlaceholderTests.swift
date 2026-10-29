@testable import SudokuEngine
import XCTest

final class EnginePlaceholderTests: XCTestCase {
    func testDefaultName() {
        let placeholder = EnginePlaceholder()
        XCTAssertEqual(placeholder.name, "SudokuEngine")
    }

    func testEqualValuesMatch() {
        XCTAssertEqual(EnginePlaceholder(), EnginePlaceholder())
    }
}
