@testable import SudokuApp
import XCTest

final class HomeScreenTests: XCTestCase {
    func testTitleIsSudoku() {
        XCTAssertEqual(HomeCopy.title, "数独")
    }

    func testMessageDescribesBoxLines() {
        XCTAssertTrue(HomeCopy.message.contains("4×4"))
        XCTAssertTrue(HomeCopy.message.contains("5×5"))
        XCTAssertTrue(HomeCopy.message.contains("9×9"))
    }
}
