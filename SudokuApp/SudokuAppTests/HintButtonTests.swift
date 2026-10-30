@testable import SudokuApp
import XCTest

/// 提示按钮：只选中并高亮确定格，不改盘面。
@MainActor
final class HintButtonTests: XCTestCase {
    func testHintSelectsCellWithoutFilling() {
        let model = makeModel(FixtureLibrary.puzzle(for: .four))
        let before = model.grid
        model.showHint()
        // 第 0 行只缺 4，行优先第一个裸单是 (0,3)
        XCTAssertEqual(model.selectedIndex, 3)
        XCTAssertEqual(model.hintedIndex, 3)
        XCTAssertTrue(model.cellStates[3].isHinted)
        XCTAssertEqual(model.grid, before, "提示不能填数字")
        XCTAssertEqual(model.statusText, BoardCopy.hinted)
    }

    func testNoHintShowsMessage() {
        // 引擎既没有确定格也没有假设格
        let blank = Grid(rules: .fourByFour)
        let empty = SamplePuzzle(rules: .fourByFour, givens: blank, solution: blank)
        let model = BoardViewModel(title: "测试", puzzle: empty, engine: ScriptedBoardEngine())
        model.showHint()
        XCTAssertNil(model.hintedIndex)
        XCTAssertNil(model.selectedIndex)
        XCTAssertEqual(model.statusText, BoardCopy.noHint)
    }

    func testHighlightClearsWhenUserActs() {
        let model = makeModel(FixtureLibrary.puzzle(for: .four))
        model.showHint()
        model.enter(4)
        XCTAssertNil(model.hintedIndex, "填数后高亮消失")
        model.showHint()
        XCTAssertNotNil(model.hintedIndex)
        model.select(index: 0)
        XCTAssertNil(model.hintedIndex, "选别的格后高亮消失")
    }

    private func makeModel(_ puzzle: SamplePuzzle) -> BoardViewModel {
        BoardViewModel(title: "测试", puzzle: puzzle, engine: EngineBoardAdapter())
    }
}
