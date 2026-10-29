@testable import SudokuApp
import XCTest

final class HomeScreenTests: XCTestCase {
    func testTitleMatchesPlaceholderCopy() {
        XCTAssertEqual(HomeCopy.title, "数独")
    }

    func testMessageIsNotEmpty() {
        XCTAssertFalse(HomeCopy.message.isEmpty)
    }
}
