import SudokuEngine
import XCTest

final class StepTechniquesTests: XCTestCase {
    /// 一个合法的完整盘面，下面的测试都从它挖空得到。
    private let solved = "483921657 967345821 251876493 548132976 729564138 136798245 372689514 814253769 695417382"

    // MARK: - 多个技巧

    /// 只空 (0,0)：宫排除、行排除、唯一余数三种不同写法；列排除与行排除同类，被去重掉。
    func testSingleBlankGivesBoxRowAndNakedSingleAfterKindDedupe() throws {
        let grid = try makeGrid("083921657" + solved.dropFirst(9))
        let steps = stepTechniques(in: grid, rules: .nineByNine)

        XCTAssertEqual(steps.map(\.technique), [.hiddenSingle, .hiddenSingle, .nakedSingle])
        XCTAssertEqual(steps.map(\.units), [[.box(0)], [.row(0)], [.row(0), .column(0), .box(0)]])
        let expected = [StepPlacement(cell: CellIndex(row: 0, column: 0), digit: 4)]
        for step in steps {
            XCTAssertEqual(step.placements, expected)
            XCTAssertTrue(step.patternCells.isEmpty)
            XCTAssertTrue(step.patternDigits.isEmpty)
        }
        try assertEffectsAreReal(steps, grid: grid, unique: true)
    }

    // MARK: - 只有一个技巧

    /// 唯一解盘面：第 6 列里的 3 只能落在第 9 宫，所以第 9 宫其余格（(6,7)）可以删掉 3。
    func testOnlyClaimingOnUniqueBoard() throws {
        let grid = try makeGrid(
            "120058407 654713298 807020150 015280900 386197542 002035081 208541009 561379824 040862015"
        )
        let steps = stepTechniques(in: grid, rules: .nineByNine)

        XCTAssertEqual(steps.count, 1)
        let step = try XCTUnwrap(steps.first)
        XCTAssertEqual(step.technique, .boxLineReduction)
        XCTAssertEqual(step.units, [.column(6), .box(8)])
        XCTAssertTrue(step.placements.isEmpty)
        XCTAssertEqual(step.patternCells, [CellIndex(row: 6, column: 6), CellIndex(row: 8, column: 6)])
        XCTAssertEqual(step.patternDigits, [])
        XCTAssertEqual(step.eliminations, [StepElimination(cell: CellIndex(row: 6, column: 7), digit: 3)])
        try assertEffectsAreReal(steps, grid: grid, unique: true)
    }

    // MARK: - 没有技巧

    func testEmptyGridReturnsEmpty() {
        XCTAssertTrue(stepTechniques(in: Grid(rules: .nineByNine), rules: .nineByNine).isEmpty)
    }

    func testCompletedGridReturnsEmpty() throws {
        XCTAssertTrue(stepTechniques(in: try makeGrid(solved), rules: .nineByNine).isEmpty)
    }

    /// 某格没有候选数时，盘面虽无直接冲突，也应返回空数组。
    func testCellWithoutCandidatesReturnsEmpty() throws {
        // (0,0)：行排除 1–4，列排除 5–8，宫排除 9。
        let text = "012340000 590000000 600000000 700000000 800000000" + String(repeating: " 000000000", count: 4)
        let grid = try makeGrid(text)
        XCTAssertTrue(stepTechniques(in: grid, rules: .nineByNine).isEmpty)
    }

    // MARK: - 纯函数

    func testDoesNotMutateGrid() throws {
        let grid = try makeGrid("083921657" + solved.dropFirst(9))
        let copy = grid
        _ = stepTechniques(in: grid, rules: .nineByNine)
        XCTAssertEqual(grid, copy)
    }

    // MARK: - 辅助

    func makeGrid(_ text: String) throws -> Grid {
        let cells = try text.filter { !$0.isWhitespace }.map { try XCTUnwrap($0.wholeNumberValue) }
        return try Grid(size: 9, cells: cells)
    }

    /// 填数落在空格、删的数字当前确实是候选数；`unique` 为真时还要和唯一解对照。
    func assertEffectsAreReal(_ steps: [StepTechnique], grid: Grid, unique: Bool = false) throws {
        var solution: Grid?
        if unique {
            XCTAssertEqual(solutionCount(grid, rules: .nineByNine, limit: 2), 1)
            solution = try XCTUnwrap(solve(grid, rules: .nineByNine))
        }
        for step in steps {
            for placement in step.placements {
                XCTAssertEqual(grid[placement.cell], Grid.emptyCell)
                XCTAssertTrue(isCandidate(placement.digit, at: placement.cell, in: grid))
                if let solution { XCTAssertEqual(placement.digit, solution[placement.cell]) }
            }
            for removed in step.eliminations {
                XCTAssertTrue(isCandidate(removed.digit, at: removed.cell, in: grid))
                if let solution { XCTAssertNotEqual(removed.digit, solution[removed.cell]) }
            }
        }
    }

    /// 9×9：数字没有出现在同行、同列、同宫里就是候选数。
    private func isCandidate(_ digit: Int, at cell: CellIndex, in grid: Grid) -> Bool {
        for row in 0 ..< 9 {
            for column in 0 ..< 9 where grid[row: row, column: column] == digit {
                let sameRow = row == cell.row
                let sameColumn = column == cell.column
                let sameBox = row / 3 == cell.row / 3 && column / 3 == cell.column / 3
                if sameRow || sameColumn || sameBox { return false }
            }
        }
        return true
    }
}
