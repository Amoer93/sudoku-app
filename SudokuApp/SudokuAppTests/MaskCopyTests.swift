@testable import SudokuApp
import XCTest

/// 「假设层」改名为「试填」后的文案断言。
final class MaskCopyTests: XCTestCase {
    func testMaskButtonTitles() {
        XCTAssertEqual(BoardCopy.startLayer, "试一试")
        XCTAssertEqual(BoardCopy.rollbackLayer, "结束试填")
    }

    func testMaskHints() {
        XCTAssertEqual(BoardCopy.startLayerHint, "开始试填，之后填的数字会用这一层的颜色显示")
        XCTAssertEqual(BoardCopy.rollbackLayerHint, "结束当前这层试填，并删除这层填的所有数字")
    }

    func testLayerStatus() {
        XCTAssertEqual(BoardCopy.layerStatus(0), "当前没有试填")
        XCTAssertEqual(BoardCopy.layerStatus(2), "当前第 2 层试填")
    }

    func testSolveButtonCopy() {
        XCTAssertEqual(BoardCopy.autoSolve, "全解")
        XCTAssertEqual(BoardCopy.multipleSolutions, "当前盘面有多个解，全解只填入其中一个。")
    }

    func testNoHintAndSolvedCopy() {
        XCTAssertEqual(BoardCopy.noHint, "当前无唯一解，可点「试一试」尝试。")
        XCTAssertEqual(BoardCopy.solved, "已填入解。")
    }

    func testCompletionCopyIsNotWarning() {
        XCTAssertEqual(BoardCopy.playerCompleted, "太棒了，这道题做完啦！")
        XCTAssertEqual(BoardCopy.autoSolved, "答案已经填好啦。想算做完，可以点「清空」再自己做一遍！")
        XCTAssertFalse(BoardNotice.playerCompleted.isWarning)
        XCTAssertFalse(BoardNotice.autoSolved.isWarning)
    }
}
