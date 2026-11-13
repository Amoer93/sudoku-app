@testable import SudokuApp
import XCTest

@MainActor
final class BoardCompletionTests: XCTestCase {
    /// 4×4 固定题里的空格（线性下标）和对应的正确数字。
    private let missingCells: [(index: Int, value: Int)] = [(3, 4), (5, 4), (8, 2), (15, 1)]

    private func makeModel() -> BoardViewModel {
        BoardViewModel(
            title: "4×4",
            puzzle: FixtureLibrary.puzzle(for: .four),
            engine: FixtureBoardEngine()
        )
    }

    private func fill(_ model: BoardViewModel, wrongAt wrongIndex: Int? = nil) {
        for item in missingCells {
            model.select(index: item.index)
            let value = item.index == wrongIndex ? 1 : item.value
            model.enter(value)
        }
    }

    func testManualFillCompletes() {
        let model = makeModel()
        fill(model)
        XCTAssertTrue(model.isPlayerCompleted)
        XCTAssertFalse(model.usedAutoSolve)
        XCTAssertEqual(model.notice, .playerCompleted)
        XCTAssertFalse(model.statusIsWarning)
    }

    func testPartialBoardIsNotCompleted() {
        let model = makeModel()
        model.select(index: 3)
        model.enter(4)
        XCTAssertFalse(model.isPlayerCompleted)
        XCTAssertEqual(model.notice, .idle)
    }

    func testAutoSolveDoesNotCount() async {
        let model = makeModel()
        await model.autoSolve()
        XCTAssertTrue(model.usedAutoSolve)
        XCTAssertFalse(model.isPlayerCompleted)
        XCTAssertEqual(model.notice, .autoSolved)
        XCTAssertEqual(model.statusText, BoardCopy.autoSolved)
    }

    func testClearAfterAutoSolveThenManualFillCounts() async {
        let model = makeModel()
        await model.autoSolve()
        model.clearUserEntries()
        XCTAssertFalse(model.usedAutoSolve)
        fill(model)
        XCTAssertTrue(model.isPlayerCompleted)
        XCTAssertEqual(model.notice, .playerCompleted)
    }

    func testUndoRedoAfterAutoSolveDoesNotCount() async {
        let model = makeModel()
        await model.autoSolve()
        model.undo()
        model.redo()
        // 撤销再重做回到满盘，仍然是全解的结果，不算做完
        XCTAssertFalse(model.grid.cells.contains(Grid.emptyCell))
        XCTAssertTrue(model.usedAutoSolve)
        XCTAssertFalse(model.isPlayerCompleted)
        XCTAssertNotEqual(model.notice, .playerCompleted)
    }

    func testUndoThenManualFillAfterAutoSolveDoesNotCount() async {
        let model = makeModel()
        await model.autoSolve()
        model.undo()
        // 撤销只是退回盘面，不能洗掉「用过全解」的记号
        fill(model)
        XCTAssertTrue(model.usedAutoSolve)
        XCTAssertFalse(model.isPlayerCompleted)
        XCTAssertNotEqual(model.notice, .playerCompleted)
    }

    func testFullBoardWithConflictIsNotCompleted() {
        let model = makeModel()
        fill(model, wrongAt: 3)
        XCTAssertFalse(model.grid.cells.contains(Grid.emptyCell))
        XCTAssertFalse(model.conflicts.isEmpty)
        XCTAssertFalse(model.isPlayerCompleted)
        XCTAssertNotEqual(model.notice, .playerCompleted)
    }

    func testCompletingInsideLayerClearsLayers() {
        let model = makeModel()
        model.startLayer()
        fill(model)
        XCTAssertEqual(model.notice, .playerCompleted)
        XCTAssertEqual(model.currentLayerDepth, 0)
    }
}
