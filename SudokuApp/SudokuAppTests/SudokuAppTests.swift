@testable import SudokuApp
import XCTest

final class HomeScreenTests: XCTestCase {
    func testTitleIsSudoku() {
        XCTAssertEqual(HomeCopy.title, "数独")
    }

    func testMessageIsNewIntro() {
        XCTAssertEqual(HomeCopy.message, "选一个难度,再点一道题开始吧！")
    }
}
