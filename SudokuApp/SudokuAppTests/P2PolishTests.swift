@testable import SudokuApp
import XCTest

/// P2 打磨：冲突时的提示、无候选数字的提示。
@MainActor
final class P2PolishTests: XCTestCase {
    func testHintBlockedWhenBoardHasConflicts() {
        let model = makeModel(FixtureLibrary.puzzle(for: .four))
        // 第 0 行是 1 2 3 空，在空格填 1 会和同行的 1 重复
        model.select(index: 3)
        model.enter(1)
        XCTAssertFalse(model.conflicts.isEmpty)
        let before = model.grid
        model.showHint()
        XCTAssertEqual(model.statusText, BoardCopy.hintBlockedByConflicts)
        XCTAssertTrue(model.statusIsWarning)
        XCTAssertNil(model.hintedIndex)
        XCTAssertEqual(model.grid, before, "提示不能改盘面")
    }

    func testNoHintMessageUnchangedWithoutConflicts() {
        let blank = Grid(rules: .fourByFour)
        let model = makeModel(SamplePuzzle(rules: .fourByFour, givens: blank, solution: blank))
        model.showHint()
        XCTAssertTrue(model.conflicts.isEmpty)
        XCTAssertEqual(model.statusText, BoardCopy.noHint)
        XCTAssertFalse(model.statusIsWarning)
    }

    func testHasNoCandidatesWhenAllDigitsBlocked() throws {
        // (0,0) 的同行有 1、2，同列有 3、4，且题目本身没有冲突
        let givens = try Grid(size: 4, cells: [
            0, 1, 2, 0,
            3, 0, 0, 0,
            4, 0, 0, 0,
            0, 0, 0, 0
        ])
        let model = makeModel(SamplePuzzle(rules: .fourByFour, givens: givens, solution: givens))
        XCTAssertTrue(model.conflicts.isEmpty)
        model.select(index: 0)

        XCTAssertFalse(model.hasNoCandidates, "自动筛选关闭时不算")

        model.isAutoFilterOn = true
        XCTAssertTrue(model.hasNoCandidates)
        XCTAssertEqual(model.statusText, BoardCopy.noCandidates)
        XCTAssertTrue(model.statusIsWarning)

        model.isAutoFilterOn = false
        XCTAssertFalse(model.hasNoCandidates)
    }

    private func makeModel(_ puzzle: SamplePuzzle) -> BoardViewModel {
        BoardViewModel(title: "测试", puzzle: puzzle, engine: EngineBoardAdapter())
    }
}
