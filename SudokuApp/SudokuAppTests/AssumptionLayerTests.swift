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
        model.startLayer()
        XCTAssertEqual(model.currentLayerDepth, 2)
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
        XCTAssertEqual(Set(styles.map(\.name)).count, 3)
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
private func makeLayerModel() -> BoardViewModel {
    let rules = Rules.fourByFour
    let grid = Grid(rules: rules)
    let puzzle = SamplePuzzle(rules: rules, givens: grid, solution: grid)
    return BoardViewModel(title: "4×4", puzzle: puzzle, engine: ScriptedBoardEngine())
}
