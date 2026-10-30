@testable import SudokuApp
import XCTest

final class FixtureBoardEngineTests: XCTestCase {
    func testSamplesRespectRules() {
        for preset in BoardPreset.allCases {
            let puzzle = FixtureLibrary.puzzle(for: preset)
            XCTAssertTrue(SampleCheck.isConsistent(puzzle), preset.title)
            XCTAssertTrue(puzzle.givens.cells.contains(Grid.emptyCell), preset.title)
        }
    }

    func testCheckerRejectsDuplicateRow() throws {
        let rules = Rules.fourByFour
        let cells = [1, 1, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1]
        let grid = try Grid(size: rules.size, cells: cells)
        let puzzle = SamplePuzzle(rules: rules, givens: grid, solution: grid)
        XCTAssertFalse(SampleCheck.isConsistent(puzzle))
    }

    func testCheckerRejectsMismatchedGiven() {
        let puzzle = FixtureLibrary.puzzle(for: .four)
        guard let offset = puzzle.givens.cells.firstIndex(where: { $0 != Grid.emptyCell }) else {
            XCTFail("示例题应该有给定数字")
            return
        }
        var givens = puzzle.givens
        let cell = CellIndex(linearIndex: offset, size: givens.size)
        givens[cell] = givens[cell] == 1 ? 2 : 1
        let broken = SamplePuzzle(rules: puzzle.rules, givens: givens, solution: puzzle.solution)
        XCTAssertFalse(SampleCheck.isConsistent(broken))
    }

    func testSolveReturnsCannedSolution() {
        let engine = FixtureBoardEngine()
        for preset in BoardPreset.allCases {
            let puzzle = FixtureLibrary.puzzle(for: preset)
            let solved = engine.solve(puzzle.givens, rules: puzzle.rules)
            XCTAssertEqual(solved, Grid?(puzzle.solution), preset.title)
            let count = engine.solutionCount(puzzle.givens, rules: puzzle.rules, limit: 2)
            XCTAssertEqual(count, 1, preset.title)
            let conflicts = engine.conflicts(in: puzzle.givens, rules: puzzle.rules)
            XCTAssertTrue(conflicts.isEmpty, preset.title)
        }
    }

    func testWrongDigitIsMarkedAndUnsolvable() {
        let engine = FixtureBoardEngine()
        let puzzle = FixtureLibrary.puzzle(for: .nine)
        guard let offset = puzzle.givens.cells.firstIndex(of: Grid.emptyCell) else {
            XCTFail("9×9 示例应该有空格")
            return
        }
        var grid = puzzle.givens
        let cell = CellIndex(linearIndex: offset, size: grid.size)
        let answer = puzzle.solution[cell]
        grid[cell] = answer == puzzle.rules.size ? 1 : answer + 1
        XCTAssertTrue(engine.conflicts(in: grid, rules: puzzle.rules).contains(cell))
        XCTAssertNil(engine.solve(grid, rules: puzzle.rules))
        XCTAssertEqual(engine.solutionCount(grid, rules: puzzle.rules, limit: 2), 0)
    }

    func testMatchingDigitIsNotAConflict() {
        let engine = FixtureBoardEngine()
        let puzzle = FixtureLibrary.puzzle(for: .five)
        guard let offset = puzzle.givens.cells.firstIndex(of: Grid.emptyCell) else {
            XCTFail("5×5 示例应该有空格")
            return
        }
        var grid = puzzle.givens
        let cell = CellIndex(linearIndex: offset, size: grid.size)
        grid[cell] = puzzle.solution[cell]
        XCTAssertFalse(engine.conflicts(in: grid, rules: puzzle.rules).contains(cell))
        XCTAssertEqual(engine.solve(grid, rules: puzzle.rules), Grid?(puzzle.solution))
    }

    func testSolutionCountHonorsLimit() {
        let engine = FixtureBoardEngine()
        let puzzle = FixtureLibrary.puzzle(for: .four)
        let count = engine.solutionCount(puzzle.givens, rules: puzzle.rules, limit: 0)
        XCTAssertEqual(count, 0)
        let capped = engine.solutionCount(puzzle.givens, rules: puzzle.rules, limit: 2)
        XCTAssertEqual(capped, 1)
    }

    func testDifferentSizeDoesNotSolve() throws {
        let engine = FixtureBoardEngine()
        let grid = try Grid(size: 4, cells: Array(repeating: Grid.emptyCell, count: 16))
        XCTAssertNil(engine.solve(grid, rules: Rules.nineByNine))
        XCTAssertEqual(engine.solutionCount(grid, rules: Rules.nineByNine, limit: 2), 0)
        XCTAssertTrue(engine.conflicts(in: grid, rules: Rules.nineByNine).isEmpty)
    }
}

/// 只检查写死的题面，不搜索解。用来防止示例数据本身就写错。
enum SampleCheck {
    static func isConsistent(_ puzzle: SamplePuzzle) -> Bool {
        let size = puzzle.rules.size
        let solution = puzzle.solution.cells
        let givens = puzzle.givens.cells
        guard size > 0, solution.count == size * size, givens.count == size * size else {
            return false
        }
        guard solution.allSatisfy({ (1 ... size).contains($0) }) else {
            return false
        }
        guard givensMatch(givens, solution) else {
            return false
        }
        return groupsAreUnique(solution, rules: puzzle.rules)
    }

    private static func givensMatch(_ givens: [Int], _ solution: [Int]) -> Bool {
        for (index, value) in givens.enumerated() where value != Grid.emptyCell {
            if value != solution[index] {
                return false
            }
        }
        return true
    }

    private static func groupsAreUnique(_ cells: [Int], rules: Rules) -> Bool {
        let size = rules.size
        if !linesUnique(cells, size: size, horizontal: true) {
            return false
        }
        if !linesUnique(cells, size: size, horizontal: false) {
            return false
        }
        return boxesUnique(cells, rules: rules)
    }

    private static func linesUnique(_ cells: [Int], size: Int, horizontal: Bool) -> Bool {
        for major in 0 ..< size {
            var seen: Set<Int> = []
            for minor in 0 ..< size {
                let index = horizontal ? major * size + minor : minor * size + major
                if seen.contains(cells[index]) {
                    return false
                }
                seen.insert(cells[index])
            }
        }
        return true
    }

    private static func boxesUnique(_ cells: [Int], rules: Rules) -> Bool {
        guard let rows = rules.boxRows, let cols = rules.boxCols else {
            return true
        }
        var row = 0
        while row < rules.size {
            var column = 0
            while column < rules.size {
                if !boxUnique(cells, rules: rules, row: row, column: column, rows: rows, cols: cols) {
                    return false
                }
                column += cols
            }
            row += rows
        }
        return true
    }

    private static func boxUnique(
        _ cells: [Int],
        rules: Rules,
        row: Int,
        column: Int,
        rows: Int,
        cols: Int
    ) -> Bool {
        var seen: Set<Int> = []
        for rowOffset in 0 ..< rows {
            for columnOffset in 0 ..< cols {
                let currentRow = row + rowOffset
                let currentColumn = column + columnOffset
                if currentRow >= rules.size || currentColumn >= rules.size {
                    return false
                }
                let value = cells[currentRow * rules.size + currentColumn]
                if seen.contains(value) {
                    return false
                }
                seen.insert(value)
            }
        }
        return seen.count == rows * cols
    }
}
