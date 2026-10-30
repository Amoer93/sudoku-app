@testable import SudokuApp
import XCTest

/// 没有确定格时，提示按钮推荐一个假设格。
@MainActor
final class HintAssumptionTests: XCTestCase {
    func testEmptyBoardRecommendsFirstCell() {
        let model = makeModel(blankPuzzle(), engine: EngineBoardAdapter())
        let before = model.grid
        model.showHint()
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertEqual(model.hintedIndex, 0)
        XCTAssertEqual(model.notice, .assumption([1, 2, 3, 4]))
        XCTAssertEqual(model.statusText, "当前无唯一解，请假设。可试：1、2、3、4")
        XCTAssertFalse(model.statusIsWarning)
        XCTAssertEqual(model.grid, before, "提示不能填数字")
    }

    func testNilFallbackShowsNoHint() {
        let model = makeModel(blankPuzzle(), engine: StubAssumptionEngine(assumption: nil))
        model.showHint()
        XCTAssertNil(model.hintedIndex)
        XCTAssertEqual(model.statusText, BoardCopy.noHint)
    }

    func testOutOfRangeAssumptionFallsBackToNoHint() {
        let bogus = BoardAssumption(cell: CellIndex(row: 9, column: 9), candidates: [1])
        let model = makeModel(blankPuzzle(), engine: StubAssumptionEngine(assumption: bogus))
        model.showHint()
        XCTAssertNil(model.hintedIndex)
        XCTAssertEqual(model.notice, .noHint)
    }

    func testConflictsTakePriorityOverAssumption() {
        let assumption = BoardAssumption(cell: CellIndex(row: 1, column: 1), candidates: [1, 2])
        let engine = StubAssumptionEngine(assumption: assumption, conflictCells: [CellIndex(row: 0, column: 0)])
        let model = makeModel(blankPuzzle(), engine: engine)
        let selectedBefore = model.selectedIndex
        model.showHint()
        XCTAssertEqual(model.notice, .hintBlockedByConflicts)
        XCTAssertNil(model.hintedIndex)
        XCTAssertEqual(model.selectedIndex, selectedBefore)
    }

    func testAssumptionHintIsFlaggedButCertainHintIsNot() {
        let model = makeModel(blankPuzzle(), engine: EngineBoardAdapter())
        model.showHint()
        XCTAssertTrue(model.cellStates[0].isHinted)
        XCTAssertTrue(model.cellStates[0].isAssumptionHint)
        XCTAssertFalse(model.cellStates[1].isAssumptionHint)
        XCTAssertTrue(model.cellStates[0].accessibilityLabel.contains("建议假设格"))
        // 选别的格后高亮消失，标记也跟着消失
        model.select(index: 1)
        XCTAssertFalse(model.cellStates[0].isAssumptionHint)
    }

    func testFullSolvedBoardShowsSolvedNotice() throws {
        let solved = try Grid(size: 4, cells: [
            1, 2, 3, 4,
            3, 4, 1, 2,
            2, 1, 4, 3,
            4, 3, 2, 1
        ])
        let full = SamplePuzzle(rules: .fourByFour, givens: solved, solution: solved)
        let model = makeModel(full, engine: EngineBoardAdapter())
        model.showHint()
        XCTAssertEqual(model.notice, .solved)
        XCTAssertNil(model.hintedIndex)
        XCTAssertNotEqual(model.statusText, BoardCopy.noHint)
    }

    private func blankPuzzle() -> SamplePuzzle {
        let blank = Grid(rules: .fourByFour)
        return SamplePuzzle(rules: .fourByFour, givens: blank, solution: blank)
    }

    private func makeModel(_ puzzle: SamplePuzzle, engine: SudokuBoardEngine) -> BoardViewModel {
        BoardViewModel(title: "测试", puzzle: puzzle, engine: engine)
    }
}

/// 测试用引擎：确定格永远没有，假设格和冲突由测试指定。
private struct StubAssumptionEngine: SudokuBoardEngine {
    var assumption: BoardAssumption?
    var conflictCells: Set<CellIndex> = []

    func conflicts(in _: Grid, rules _: Rules) -> Set<CellIndex> {
        conflictCells
    }

    func solve(_: Grid, rules _: Rules) -> Grid? {
        nil
    }

    func solutionCount(_: Grid, rules _: Rules, limit _: Int) -> Int {
        0
    }

    func assumptionCell(in _: Grid, rules _: Rules) -> BoardAssumption? {
        assumption
    }
}
