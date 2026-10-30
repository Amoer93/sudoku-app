@testable import SudokuApp
import XCTest

/// 假设层：嵌套、按层标记、逐层撤回，以及各层颜色要能区分。
@MainActor
final class AssumptionLayerTests: XCTestCase {
    func testStartLayerIncrementsDepth() {
        let model = makeLayerModel()
        XCTAssertEqual(model.currentLayerDepth, 0)
        model.startLayer()
        XCTAssertEqual(model.currentLayerDepth, 1)
        // 新层要先填过数字才能再开下一层
        fill(model, index: 0, value: 1)
        model.startLayer()
        XCTAssertEqual(model.currentLayerDepth, 2)
    }

    func testCannotStartLayerOnTopOfEmptyLayer() {
        let model = makeLayerModel()
        XCTAssertTrue(model.canStartLayer)
        model.startLayer()
        XCTAssertFalse(model.canStartLayer)
        model.startLayer()
        XCTAssertEqual(model.currentLayerDepth, 1)
        fill(model, index: 0, value: 1)
        XCTAssertTrue(model.canStartLayer)
    }

    func testUndoPastLayerOpeningPopsTheLayer() {
        let model = makeLayerModel()
        fill(model, index: 0, value: 1)
        model.startLayer()
        model.undo()
        XCTAssertEqual(model.currentLayerDepth, 0)
        XCTAssertEqual(model.grid.cells[0], 0)
        // 层已经不在了，回撤是空操作，不会把已撤销的数字写回来
        let before = model.grid
        model.rollbackLayer()
        XCTAssertEqual(model.grid, before)
    }

    func testUndoPastNestedLayersPopsAllOfThem() {
        let model = makeLayerModel()
        model.startLayer()
        fill(model, index: 0, value: 1)
        model.startLayer()
        fill(model, index: 1, value: 2)
        model.undo()
        XCTAssertEqual(model.currentLayerDepth, 2)
        // 第二层在撤销栈长度 1 处开启，退到 0 步时它被弹掉；第一层开在 0 处，还在
        model.undo()
        XCTAssertEqual(model.currentLayerDepth, 1)
    }

    func testClearUserEntriesDropsAllLayers() {
        let model = makeLayerModel()
        model.startLayer()
        fill(model, index: 0, value: 1)
        model.clearUserEntries()
        XCTAssertEqual(model.currentLayerDepth, 0)
        XCTAssertEqual(model.layerDepth(at: 0), 0)
    }

    func testAutoSolveDropsAllLayers() async {
        let solved = (try? Grid(size: 4, cells: Array(repeating: 1, count: 16))) ?? Grid(rules: .fourByFour)
        let model = makeLayerModel(engine: ScriptedBoardEngine(solvedGrid: solved))
        model.startLayer()
        fill(model, index: 0, value: 1)
        await model.autoSolve()
        XCTAssertEqual(model.currentLayerDepth, 0)
        XCTAssertEqual(model.layerDepth(at: 0), 0)
        XCTAssertEqual(model.layerDepth(at: 5), 0)
    }

    func testUndoAfterClearLeavesNoGhostLayerDepth() {
        let model = makeLayerModel()
        model.startLayer()
        fill(model, index: 0, value: 1)
        model.clearUserEntries()
        model.undo()
        XCTAssertEqual(model.grid.cells[0], 1)
        XCTAssertEqual(model.layerDepth(at: 0), 0)
    }

    func testUndoAfterAutoSolveLeavesNoGhostLayerDepth() async {
        let solved = (try? Grid(size: 4, cells: Array(repeating: 1, count: 16))) ?? Grid(rules: .fourByFour)
        let model = makeLayerModel(engine: ScriptedBoardEngine(solvedGrid: solved))
        model.startLayer()
        fill(model, index: 0, value: 1)
        await model.autoSolve()
        model.undo()
        XCTAssertEqual(model.layerDepth(at: 0), 0)
    }

    func testRedoPastPoppedLayerKeepsDepthWithinCurrentLayers() {
        let model = makeLayerModel()
        fill(model, index: 0, value: 1)
        model.startLayer()
        fill(model, index: 1, value: 2)
        model.undo()
        model.undo()
        XCTAssertEqual(model.currentLayerDepth, 0)
        model.redo()
        model.redo()
        XCTAssertEqual(model.grid.cells[1], 2)
        XCTAssertLessThanOrEqual(model.layerDepth(at: 1), model.currentLayerDepth)
    }

    func testAccessibilityLabelMentionsLayerDepth() {
        let model = makeLayerModel()
        model.startLayer()
        fill(model, index: 0, value: 1)
        let states = model.cellStates
        XCTAssertTrue(states[0].accessibilityLabel.contains("第 1 层假设"))
        XCTAssertFalse(states[1].accessibilityLabel.contains("层假设"))
    }

    func testEntriesAreTaggedWithLayerDepth() {
        let model = makeLayerModel()
        fill(model, index: 0, value: 1)
        model.startLayer()
        fill(model, index: 1, value: 2)
        model.startLayer()
        fill(model, index: 2, value: 3)
        XCTAssertEqual(model.layerDepth(at: 0), 0)
        XCTAssertEqual(model.layerDepth(at: 1), 1)
        XCTAssertEqual(model.layerDepth(at: 2), 2)
        XCTAssertEqual(model.layerDepth(at: 3), 0)
    }

    func testRollbackRemovesOnlyTopLayerEntries() {
        let model = makeLayerModel()
        fill(model, index: 0, value: 1)
        model.startLayer()
        fill(model, index: 1, value: 2)
        model.rollbackLayer()
        XCTAssertEqual(model.grid.cells[0], 1)
        XCTAssertEqual(model.grid.cells[1], 0)
        XCTAssertEqual(model.currentLayerDepth, 0)
        XCTAssertEqual(model.layerDepth(at: 0), 0)
    }

    func testRollbackRestoresOverwrittenValue() {
        let model = makeLayerModel()
        fill(model, index: 0, value: 1)
        model.startLayer()
        fill(model, index: 0, value: 4)
        XCTAssertEqual(model.layerDepth(at: 0), 1)
        model.rollbackLayer()
        XCTAssertEqual(model.grid.cells[0], 1)
        XCTAssertEqual(model.layerDepth(at: 0), 0)
    }

    func testNestedLayersRollBackOneAtATime() {
        let model = makeLayerModel()
        model.startLayer()
        fill(model, index: 0, value: 1)
        model.startLayer()
        fill(model, index: 1, value: 2)
        model.rollbackLayer()
        XCTAssertEqual(model.currentLayerDepth, 1)
        XCTAssertEqual(model.grid.cells[0], 1)
        XCTAssertEqual(model.grid.cells[1], 0)
        model.rollbackLayer()
        XCTAssertEqual(model.currentLayerDepth, 0)
        XCTAssertEqual(model.grid.cells[0], 0)
    }

    func testRollbackDropsLayerUndoEntries() {
        let model = makeLayerModel()
        fill(model, index: 0, value: 1)
        model.startLayer()
        fill(model, index: 1, value: 2)
        model.rollbackLayer()
        model.undo()
        // 撤销只回到层外那一步，不会把已撤回的数字带回来
        XCTAssertEqual(model.grid.cells[0], 0)
        XCTAssertEqual(model.grid.cells[1], 0)
        XCTAssertFalse(model.canUndo)
    }

    func testRollbackWithoutLayerIsNoOp() {
        let model = makeLayerModel()
        fill(model, index: 0, value: 1)
        model.rollbackLayer()
        XCTAssertEqual(model.currentLayerDepth, 0)
        XCTAssertEqual(model.grid.cells[0], 1)
        XCTAssertFalse(model.canRollbackLayer)
    }

    func testPaletteIsDistinctForFirstThreeDepths() {
        XCTAssertNil(AssumptionLayerStyle.style(forDepth: 0))
        let styles = (1 ... 3).compactMap { depth in
            AssumptionLayerStyle.style(forDepth: depth)
        }
        XCTAssertEqual(styles.count, 3)
        XCTAssertEqual(Set(styles.map { $0.name }).count, 3)
        XCTAssertEqual(Set(styles.map(\.opacity)).count, 3)
        XCTAssertGreaterThan(styles[0].opacity, styles[1].opacity)
        XCTAssertGreaterThan(styles[1].opacity, styles[2].opacity)
    }
}

/// 选中并填入一个数字。
@MainActor
private func fill(_ model: BoardViewModel, index: Int, value: Int) {
    if model.selectedIndex != index {
        model.select(index: index)
    }
    model.enter(value)
}

@MainActor
private func makeLayerModel(engine: ScriptedBoardEngine = ScriptedBoardEngine()) -> BoardViewModel {
    let rules = Rules.fourByFour
    let grid = Grid(rules: rules)
    let puzzle = SamplePuzzle(rules: rules, givens: grid, solution: grid)
    return BoardViewModel(title: "4×4", puzzle: puzzle, engine: engine)
}
