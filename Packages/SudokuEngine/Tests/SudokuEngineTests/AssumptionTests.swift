import SudokuEngine
import XCTest

final class AssumptionTests: XCTestCase {
    // MARK: - 返回 nil 的场景

    /// 盘面存在冲突时应返回 nil。
    func testNilWhenConflictsExist() throws {
        let grid = try makeGrid(size: 4, "1001 0000 0000 0000")
        XCTAssertNil(bestAssumption(in: grid, rules: .fourByFour))
        XCTAssertNil(hint(in: grid, rules: .fourByFour))
    }

    /// 盘面已满时应返回 nil。
    func testNilWhenGridIsFull() throws {
        let grid = try makeGrid(size: 4, "1234 3412 2341 4123")
        XCTAssertNil(bestAssumption(in: grid, rules: .fourByFour))
        XCTAssertNil(hint(in: grid, rules: .fourByFour))
    }

    /// 存在确定提示时应返回 nil。
    func testNilWhenHintAvailable() throws {
        let grid = try makeGrid(size: 4, "1230 0000 0000 0000")
        XCTAssertNotNil(hint(in: grid, rules: .fourByFour))
        XCTAssertNil(bestAssumption(in: grid, rules: .fourByFour))
    }

    /// 4×4 中 (0,0) 没有候选数（盘面矛盾）时应返回 nil。
    func testNilWhenEmptyCellHasNoCandidatesFourByFour() throws {
        let grid = try makeGrid(size: 4, "0230 4000 1000 0000")
        XCTAssertTrue(conflicts(in: grid, rules: .fourByFour).isEmpty)
        XCTAssertNil(bestAssumption(in: grid, rules: .fourByFour))
    }

    /// 9×9 中 (0,0) 没有候选数（盘面矛盾）时应返回 nil。
    func testNilWhenEmptyCellHasNoCandidatesNineByNine() throws {
        let text = "012345678 900000000" + String(repeating: " 000000000", count: 7)
        let grid = try makeGrid(size: 9, text)
        XCTAssertTrue(conflicts(in: grid, rules: .nineByNine).isEmpty)
        XCTAssertNil(bestAssumption(in: grid, rules: .nineByNine))
    }

    // MARK: - MRV 与候选数

    /// 空 9×9 棋盘所有空格候选数相同，应选行优先下标最小的 (0,0)。
    func testEmptyNineByNineTieGoesToSmallestIndex() throws {
        let grid = Grid(rules: .nineByNine)
        let assumption = bestAssumption(in: grid, rules: .nineByNine)
        XCTAssertEqual(assumption?.target, CellIndex(row: 0, column: 0))
        XCTAssertEqual(assumption?.candidates, Array(1 ... 9))
        XCTAssertNil(hint(in: grid, rules: .nineByNine))
    }

    /// 9×9 中 MRV 应选出候选数严格更少的非首格。
    func testNineByNineMRVPicksNonFirstCell() throws {
        let grid = try makeGrid(size: 9, """
        000000001
        000000002
        000000003
        000000004
        000000005
        000000006
        000000007
        000000000
        000000000
        """)
        let assumption = try XCTUnwrap(bestAssumption(in: grid, rules: .nineByNine))
        XCTAssertEqual(assumption.target, CellIndex(row: 7, column: 8))
        XCTAssertEqual(assumption.candidates, [8, 9])
        XCTAssertNil(hint(in: grid, rules: .nineByNine))
    }

    /// 空 4×4 棋盘应返回 (0,0) 及其全部候选数。
    func testEmptyFourByFour() throws {
        let grid = Grid(rules: .fourByFour)
        let assumption = bestAssumption(in: grid, rules: .fourByFour)
        XCTAssertEqual(assumption?.target, CellIndex(row: 0, column: 0))
        XCTAssertEqual(assumption?.candidates, [1, 2, 3, 4])
        XCTAssertNil(hint(in: grid, rules: .fourByFour))
    }

    /// 5×5 无宫约束：同一“宫”内可重复数字而不冲突，候选数按行、列排除。
    func testFiveByFiveNoBoxConstraint() throws {
        let grid = try makeGrid(size: 5, "10000 01000 00000 00000 00000")
        XCTAssertTrue(conflicts(in: grid, rules: .fiveByFive).isEmpty)
        let assumption = try XCTUnwrap(bestAssumption(in: grid, rules: .fiveByFive))
        XCTAssertEqual(assumption.target, CellIndex(row: 0, column: 1))
        XCTAssertEqual(assumption.candidates, [2, 3, 4, 5])
        XCTAssertNil(hint(in: grid, rules: .fiveByFive))
    }

    /// 5×5 无宫：(0,0) 填 1 后，(1,1) 若在 9×9 式的宫中会排除 1，这里候选数仍包含 1。
    func testFiveByFiveSameAreaKeepsCandidate() throws {
        let grid = try makeGrid(size: 5, "10000 30200 04000 00000 00000")
        let assumption = try XCTUnwrap(bestAssumption(in: grid, rules: .fiveByFive))
        XCTAssertEqual(assumption.target, CellIndex(row: 1, column: 1))
        XCTAssertEqual(assumption.candidates, [1, 5])
        XCTAssertNil(hint(in: grid, rules: .fiveByFive))
    }

    // MARK: - 辅助

    private func makeGrid(size: Int, _ text: String) throws -> Grid {
        let cells = try text.filter { !$0.isWhitespace }.map { try XCTUnwrap($0.wholeNumberValue) }
        return try Grid(size: size, cells: cells)
    }
}
