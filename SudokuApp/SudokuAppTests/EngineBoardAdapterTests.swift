@testable import SudokuApp
// 只按需导入一个函数：显式声明依赖 SudokuEngine，
// 又不会把它的 Grid/Rules 引进来和 App 的同名类型冲突。
import func SudokuEngine.solutionCount
import XCTest

/// 只测转换，不调用引擎（引擎求解还是 fatalError）。
final class EngineBoardAdapterTests: XCTestCase {
    func testConvertKeepsShapeAndCells() throws {
        let grid = try Grid(size: 4, cells: [0, 1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4])
        let converted = try XCTUnwrap(EngineBoardAdapter.convert(grid, .fourByFour))
        XCTAssertEqual(converted.0.cells, grid.cells)
        XCTAssertEqual(converted.0.size, 4)
        XCTAssertEqual(converted.1.boxRows, 2)
        XCTAssertEqual(converted.1.boxCols, 2)
    }

    func testConvertRejectsMismatchedSize() {
        let grid = Grid(rules: .fourByFour)
        XCTAssertNil(EngineBoardAdapter.convert(grid, .nineByNine))
    }

    func testZeroLimitSkipsEngine() {
        let adapter = EngineBoardAdapter()
        XCTAssertEqual(adapter.solutionCount(Grid(rules: .fourByFour), rules: .fourByFour, limit: 0), 0)
    }
}
