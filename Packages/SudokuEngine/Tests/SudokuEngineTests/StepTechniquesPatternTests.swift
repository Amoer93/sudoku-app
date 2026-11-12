import SudokuEngine
import XCTest

/// 区块与数对技巧的结果字段测试，复用 StepTechniquesTests 里的辅助方法。
extension StepTechniquesTests {
    // MARK: - 辅助

    private func cell(_ row: Int, _ column: Int) -> CellIndex {
        CellIndex(row: row, column: column)
    }

    private func removal(_ row: Int, _ column: Int, _ digits: Int...) -> [StepElimination] {
        digits.map { StepElimination(cell: cell(row, column), digit: $0) }
    }

    private func steps(for text: String) throws -> (Grid, [StepTechnique]) {
        let grid = try makeGrid(text)
        return (grid, stepTechniques(in: grid, rules: .nineByNine))
    }

    // MARK: - 宫区块与多种技巧

    /// 宫排除、行列排除、宫区块是三种不同的技巧。同一格的列排除与行排除同类，只留行排除。
    func testHiddenSinglesAndPointingAreDifferentKinds() throws {
        let (grid, steps) = try steps(
            for: "000002638 700000005 006509402 001900320 200004500 670080000 502000009 060005200 937000000"
        )

        XCTAssertEqual(steps.map(\.technique), [.hiddenSingle, .hiddenSingle, .pointing])
        XCTAssertEqual(steps.map(\.units), [[.box(0)], [.row(1)], [.box(1), .row(1)]])
        XCTAssertEqual(steps[0].placements, [StepPlacement(cell: cell(1, 1), digit: 2)])
        XCTAssertEqual(steps[1].placements, [StepPlacement(cell: cell(1, 1), digit: 2)])
        for step in steps.prefix(2) {
            XCTAssertTrue(step.patternCells.isEmpty)
            XCTAssertTrue(step.patternDigits.isEmpty)
        }
        XCTAssertEqual(steps[2].patternCells, [cell(1, 3), cell(1, 5)])
        XCTAssertEqual(steps[2].patternDigits, [])
        XCTAssertEqual(steps[2].eliminations, removal(1, 1, 8) + removal(1, 2, 8))
        try assertEffectsAreReal(steps, grid: grid, unique: true)
    }

    // MARK: - 显性数对

    func testNakedPairExposesPairCellsAndDigits() throws {
        let (grid, steps) = try steps(
            for: "037600002 000009605 060420700 003041076 000030001 000002453 006200000 008000004 392854167"
        )

        XCTAssertEqual(steps.map(\.technique), [.pointing, .boxLineReduction, .nakedPair])
        XCTAssertEqual(steps[0].units, [.box(1), .column(5)])
        XCTAssertEqual(steps[0].patternCells, [cell(0, 5), cell(2, 5)])
        XCTAssertEqual(steps[0].eliminations, removal(4, 5, 5))
        XCTAssertEqual(steps[1].units, [.column(3), .box(4)])
        XCTAssertEqual(steps[1].patternCells, [cell(3, 3), cell(4, 3)])
        XCTAssertEqual(steps[1].eliminations, removal(4, 5, 5))

        let pair = steps[2]
        XCTAssertEqual(pair.units, [.box(2)])
        XCTAssertEqual(pair.patternCells, [cell(0, 6), cell(2, 8)])
        XCTAssertEqual(pair.patternDigits, [8, 9])
        XCTAssertEqual(pair.eliminations, removal(0, 7, 8, 9) + removal(1, 7, 8) + removal(2, 7, 8, 9))
        try assertEffectsAreReal(steps, grid: grid, unique: true)
    }

    // MARK: - 隐性数对

    func testHiddenPairExposesPairCellsAndDigits() throws {
        let (grid, steps) = try steps(
            for: "086000000 001009030 003010580 032000600 700000004 000502008 300400801 000900000 207060090"
        )

        XCTAssertEqual(steps.map(\.technique), [.pointing, .boxLineReduction, .hiddenPair])
        XCTAssertEqual(steps[0].units, [.box(2), .column(8)])
        XCTAssertEqual(steps[0].patternCells, [cell(1, 8), cell(2, 8)])
        XCTAssertEqual(steps[0].eliminations, removal(7, 8, 6))
        XCTAssertEqual(steps[1].units, [.row(5), .box(3)])
        XCTAssertEqual(steps[1].patternCells, [cell(5, 0), cell(5, 1)])
        XCTAssertEqual(steps[1].eliminations, removal(4, 1, 6))

        let pair = steps[2]
        XCTAssertEqual(pair.units, [.box(0)])
        XCTAssertEqual(pair.patternCells, [cell(1, 1), cell(2, 1)])
        XCTAssertEqual(pair.patternDigits, [2, 7])
        XCTAssertEqual(pair.eliminations, removal(1, 1, 4, 5) + removal(2, 1, 4, 9))
        try assertEffectsAreReal(steps, grid: grid, unique: true)
    }
}
