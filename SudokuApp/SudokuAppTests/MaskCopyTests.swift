@testable import SudokuApp
import XCTest

/// 「假设层」改名为「蒙版」后的文案断言。
final class MaskCopyTests: XCTestCase {
    func testMaskButtonTitles() {
        XCTAssertEqual(BoardCopy.startLayer, "新增蒙版")
        XCTAssertEqual(BoardCopy.rollbackLayer, "删除该层")
    }

    func testMaskHints() {
        XCTAssertEqual(BoardCopy.startLayerHint, "新增一层蒙版，之后填的数字会用这一层的颜色显示")
        XCTAssertEqual(BoardCopy.rollbackLayerHint, "删除当前这层蒙版填的所有数字")
    }

    func testLayerStatus() {
        XCTAssertEqual(BoardCopy.layerStatus(0), "当前没有蒙版")
        XCTAssertEqual(BoardCopy.layerStatus(2), "当前第 2 层蒙版")
    }

    func testNoHintAndSolvedCopy() {
        XCTAssertEqual(BoardCopy.noHint, "当前无唯一解，可新增蒙版尝试。")
        XCTAssertEqual(BoardCopy.solved, "已填入解。")
    }
}
