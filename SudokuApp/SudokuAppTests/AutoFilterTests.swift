@testable import SudokuApp
import XCTest

/// 自动筛选：同行、同列、同宫已有的数字要被禁用。
@MainActor
final class AutoFilterTests: XCTestCase {
    func testNineByNineRowColumnAndBox() throws {
        var cells = Array(repeating: Grid.emptyCell, count: 81)
        cells[4 * 9 + 0] = 1 // 同行
        cells[0 * 9 + 4] = 2 // 同列
        cells[3 * 9 + 3] = 3 // 同宫（中间宫左上角）
        cells[5 * 9 + 5] = 4 // 同宫
        cells[0 * 9 + 0] = 9 // 不同行列宫，不应禁用
        cells[4 * 9 + 4] = 7 // 格子自己的值不算
        let grid = try Grid(size: 9, cells: cells)
        let used = PeerValues.used(in: grid, rules: .nineByNine, at: CellIndex(row: 4, column: 4))
        XCTAssertEqual(used, [1, 2, 3, 4])
    }

    func testFiveByFiveHasNoBox() throws {
        var cells = Array(repeating: Grid.emptyCell, count: 25)
        cells[0 * 5 + 2] = 1 // 同行
        cells[3 * 5 + 1] = 2 // 同列
        cells[1 * 5 + 0] = 3 // 若有宫会算进去，5×5 不该算
        let grid = try Grid(size: 5, cells: cells)
        let used = PeerValues.used(in: grid, rules: .fiveByFive, at: CellIndex(row: 0, column: 1))
        XCTAssertEqual(used, [1, 2])
    }

    func testFourByFourBox() throws {
        let grid = try Grid(size: 4, cells: [0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        let used = PeerValues.used(in: grid, rules: .fourByFour, at: CellIndex(row: 0, column: 0))
        XCTAssertEqual(used, [2])
    }

    func testModelDisablesPeersWhenOn() {
        let model = makeModel()
        model.isAutoFilterOn = true
        // 第 0 行第 3 列是空格：行里 1、2、3，列里 2、3，宫里 1、2、3
        model.select(index: 3)
        XCTAssertEqual(model.disabledValues, [1, 2, 3])
        model.enter(1)
        XCTAssertEqual(model.grid.cells[3], Grid.emptyCell, "被筛掉的数字不应写入")
        model.enter(4)
        XCTAssertEqual(model.grid.cells[3], 4)
    }

    func testToggleOffDisablesNothing() {
        let model = makeModel()
        model.select(index: 3)
        XCTAssertTrue(model.disabledValues.isEmpty)
        model.enter(1)
        XCTAssertEqual(model.grid.cells[3], 1, "关闭时行为不变")
    }

    func testGivenCellOrNoSelectionDisablesNothing() {
        let model = makeModel()
        model.isAutoFilterOn = true
        XCTAssertTrue(model.disabledValues.isEmpty)
        model.select(index: 0)
        XCTAssertTrue(model.disabledValues.isEmpty)
    }

    private func makeModel() -> BoardViewModel {
        let puzzle = FixtureLibrary.puzzle(for: .four)
        return BoardViewModel(title: "测试", puzzle: puzzle, engine: FixtureBoardEngine())
    }
}
