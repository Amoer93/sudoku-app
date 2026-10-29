@testable import SudokuApp
import XCTest

final class BoardViewModelTests: XCTestCase {
    func testEnterUndoAndRedo() async {
        let model = await makeModel()
        await model.select(index: 5)
        await model.enter(3)
        var cells = await model.grid.cells
        XCTAssertEqual(cells[5], 3)
        await model.undo()
        cells = await model.grid.cells
        XCTAssertEqual(cells[5], 0)
        let canRedo = await model.canRedo
        XCTAssertTrue(canRedo)
        await model.redo()
        cells = await model.grid.cells
        XCTAssertEqual(cells[5], 3)
    }

    func testRedoIsDroppedAfterNewEntry() async {
        let model = await makeModel()
        await model.select(index: 1)
        await model.enter(2)
        await model.undo()
        let ready = await model.canRedo
        XCTAssertTrue(ready)
        await model.enter(3)
        let dropped = await model.canRedo
        XCTAssertFalse(dropped)
        let cells = await model.grid.cells
        XCTAssertEqual(cells[1], 3)
    }

    func testSameValueDoesNotPushUndo() async {
        let model = await makeModel()
        await model.select(index: 1)
        await model.enter(2)
        await model.enter(2)
        await model.undo()
        let cells = await model.grid.cells
        XCTAssertEqual(cells[1], 0)
        let canUndo = await model.canUndo
        XCTAssertFalse(canUndo)
    }

    func testGivenCannotChange() async {
        var seed = Array(repeating: 0, count: 16)
        seed[0] = 2
        let model = await makeModel(cells: seed)
        await model.select(index: 0)
        let warning = await model.statusIsWarning
        XCTAssertTrue(warning)
        let hint = await model.statusText
        XCTAssertEqual(hint, BoardCopy.givenLocked)
        await model.enter(3)
        let cells = await model.grid.cells
        XCTAssertEqual(cells[0], 2)
        let notice = await model.notice
        XCTAssertEqual(notice, .givenLocked)
        let canUndo = await model.canUndo
        XCTAssertFalse(canUndo)
    }

    func testOutOfRangeDigitIsIgnored() async {
        let model = await makeModel()
        await model.select(index: 1)
        await model.enter(8)
        let cells = await model.grid.cells
        XCTAssertEqual(cells[1], 0)
        let canUndo = await model.canUndo
        XCTAssertFalse(canUndo)
    }

    func testClearSelectedAndClearAll() async {
        var seed = Array(repeating: 0, count: 16)
        seed[0] = 1
        let model = await makeModel(cells: seed)
        await model.select(index: 1)
        await model.enter(2)
        await model.select(index: 2)
        await model.enter(3)
        await model.clearSelected()
        var cells = await model.grid.cells
        XCTAssertEqual(cells[2], 0)
        XCTAssertEqual(cells[1], 2)
        await model.clearUserEntries()
        cells = await model.grid.cells
        XCTAssertEqual(cells[0], 1)
        XCTAssertEqual(cells[1], 0)
        let notice = await model.notice
        XCTAssertEqual(notice, .cleared)
        await model.undo()
        cells = await model.grid.cells
        XCTAssertEqual(cells[1], 2)
    }

    func testSelectionToggleAndInvalidIndex() async {
        let model = await makeModel()
        let initial = await model.statusText
        XCTAssertEqual(initial, BoardCopy.selectCell)
        await model.select(index: 3)
        let selected = await model.selectedIndex
        XCTAssertEqual(selected, 3)
        await model.select(index: 3)
        await model.select(index: -1)
        await model.select(index: 99)
        let cleared = await model.selectedIndex
        XCTAssertNil(cleared)
    }

    func testCellStatesUseEngineConflicts() async {
        let engine = ValueConflictEngine()
        let model = await makeModel(engine: engine)
        await model.select(index: 4)
        await model.enter(4)
        var states = await model.cellStates
        XCTAssertEqual(states[6].row, 1)
        XCTAssertEqual(states[6].column, 2)
        XCTAssertTrue(states[4].isConflict)
        XCTAssertTrue(states[4].accessibilityLabel.contains("冲突"))
        await model.enter(1)
        states = await model.cellStates
        XCTAssertFalse(states[4].isConflict)
    }

    func testLoadSolutionCount() async {
        let engine = ScriptedBoardEngine(countedSolutions: 2)
        let model = await makeModel(engine: engine)
        let before = await model.solutionCountText
        XCTAssertEqual(before, BoardCopy.checkingSolutions)
        await model.loadSolutionCount()
        let text = await model.solutionCountText
        XCTAssertEqual(text, BoardCopy.multipleSolutions)
        let warning = await model.solutionCountIsWarning
        XCTAssertFalse(warning)
    }

    func testAutoSolveAppliesEngineResult() async {
        let solved = Grid(cells: Array(repeating: 7, count: 16))
        let engine = ScriptedBoardEngine(solvedGrid: solved, countedSolutions: 1)
        let model = await makeModel(engine: engine)
        await model.autoSolve()
        let grid = await model.grid
        XCTAssertEqual(grid, solved)
        let notice = await model.notice
        XCTAssertEqual(notice, .solved)
        let text = await model.solutionCountText
        XCTAssertEqual(text, BoardCopy.uniqueSolution)
        await model.undo()
        let restored = await model.grid.cells
        XCTAssertEqual(restored, Array(repeating: 0, count: 16))
    }

    func testFailedSolveKeepsTheGrid() async {
        let engine = ScriptedBoardEngine(solvedGrid: nil, countedSolutions: 0)
        let model = await makeModel(engine: engine)
        await model.select(index: 2)
        await model.enter(3)
        await model.autoSolve()
        let cells = await model.grid.cells
        XCTAssertEqual(cells[2], 3)
        let notice = await model.notice
        XCTAssertEqual(notice, .unsolvable)
        let count = await model.solutionCount
        XCTAssertEqual(count, 0)
        let warning = await model.solutionCountIsWarning
        XCTAssertTrue(warning)
    }

    func testSolveOfSameGridDoesNotPushUndo() async {
        let empty = Grid(cells: Array(repeating: 0, count: 16))
        let model = await makeModel(engine: ScriptedBoardEngine(solvedGrid: empty))
        await model.autoSolve()
        let canUndo = await model.canUndo
        XCTAssertFalse(canUndo)
        let notice = await model.notice
        XCTAssertEqual(notice, .solved)
    }

    @MainActor
    private func makeModel(
        cells: [Int]? = nil,
        engine: any SudokuBoardEngine = ScriptedBoardEngine()
    ) -> BoardViewModel {
        let rules = Rules(size: 4, boxRows: 2, boxCols: 2)
        let values = cells ?? Array(repeating: 0, count: 16)
        let grid = Grid(cells: values)
        let puzzle = SamplePuzzle(rules: rules, givens: grid, solution: grid)
        return BoardViewModel(title: "4×4", puzzle: puzzle, engine: engine)
    }
}

/// 测试用引擎。冲突和答案都由用例指定，视图模型不应该自己改。
struct ScriptedBoardEngine: SudokuBoardEngine {
    var conflictIndexes: Set<Int> = []
    var solvedGrid: Grid?
    var countedSolutions = 1

    func conflicts(in grid: Grid, rules: Rules) -> Set<Int> {
        conflictIndexes
    }

    func solve(_ grid: Grid, rules: Rules) -> Grid? {
        solvedGrid
    }

    func solutionCount(_ grid: Grid, rules: Rules) -> Int {
        countedSolutions
    }
}

/// 数字 4 标成冲突，用来确认每次输入都会重新问引擎。
final class ValueConflictEngine: SudokuBoardEngine, Sendable {
    func conflicts(in grid: Grid, rules: Rules) -> Set<Int> {
        var indexes: Set<Int> = []
        for (index, value) in grid.cells.enumerated() where value == 4 {
            indexes.insert(index)
        }
        return indexes
    }

    func solve(_ grid: Grid, rules: Rules) -> Grid? {
        nil
    }

    func solutionCount(_ grid: Grid, rules: Rules) -> Int {
        0
    }
}
