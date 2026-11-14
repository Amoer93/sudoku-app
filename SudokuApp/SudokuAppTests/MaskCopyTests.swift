@testable import SudokuApp
import XCTest

/// 「假设层」改成「试一试」后的文案断言。
final class MaskCopyTests: XCTestCase {
    func testMaskButtonTitles() {
        XCTAssertEqual(BoardCopy.startLayer, "试一试")
        XCTAssertEqual(BoardCopy.rollbackLayer, "不试了")
    }

    func testMaskHints() {
        XCTAssertEqual(BoardCopy.startLayerHint, "开始试试。这之后填的数字，会换成新的颜色。")
        XCTAssertEqual(BoardCopy.rollbackLayerHint, "取消这次试试，这次填的数字都会清掉。")
    }

    func testLayerStatus() {
        XCTAssertEqual(BoardCopy.layerStatus(0), "")
        XCTAssertEqual(BoardCopy.layerStatus(1), "正在试试。")
        XCTAssertEqual(BoardCopy.layerStatus(2), "正在试试，第 2 层。")
    }

    func testSolveButtonCopy() {
        XCTAssertEqual(BoardCopy.autoSolve, "全解")
        XCTAssertEqual(BoardCopy.multipleSolutions, "现在这样填，有好几种答案。「全解」只会填其中一种。")
    }

    func testNoHintAndSolvedCopy() {
        XCTAssertEqual(BoardCopy.noHint, "现在还不能确定，可以点「试一试」。")
        XCTAssertEqual(BoardCopy.solved, "答案已经填好了。")
    }

    func testCompletionCopyIsNotWarning() {
        XCTAssertEqual(BoardCopy.playerCompleted, "太棒了，这道题做完啦！")
        XCTAssertEqual(BoardCopy.autoSolved, "答案已经填好啦。想算做完，可以点「清空」再自己做一遍！")
        XCTAssertFalse(BoardNotice.playerCompleted.isWarning)
        XCTAssertFalse(BoardNotice.autoSolved.isWarning)
    }
}
