@testable import SudokuApp
// 只按需导入一个函数：显式声明依赖 SudokuEngine，
// 又不会把它的 Grid/Rules 引进来和 App 的同名类型冲突。
import func SudokuEngine.solutionCount
import XCTest

/// 测类型转换，以及默认引擎真的能解内置题目。
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

    /// 默认路径走真引擎：每道内置题都能解出、唯一解，并且和写死的答案一致。
    func testAdapterSolvesBuiltInPuzzles() throws {
        let adapter = EngineBoardAdapter()
        // 防止题库为空时循环一次不跑也算通过
        XCTAssertEqual(Set(FixtureLibrary.all.map(\.rules.size)), [4, 5, 9])
        for puzzle in FixtureLibrary.all {
            let solved = try XCTUnwrap(adapter.solve(puzzle.givens, rules: puzzle.rules))
            XCTAssertEqual(solved, puzzle.solution)
            XCTAssertEqual(adapter.solutionCount(puzzle.givens, rules: puzzle.rules, limit: 2), 1)
            XCTAssertTrue(adapter.conflicts(in: puzzle.givens, rules: puzzle.rules).isEmpty)
        }
    }
}
