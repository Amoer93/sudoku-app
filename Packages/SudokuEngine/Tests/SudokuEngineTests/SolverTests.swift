import SudokuEngine
import XCTest

final class SolverTests: XCTestCase {
    // MARK: - 4×4 / 5×5 / 9×9

    func testSolvesFourByFourPuzzle() throws {
        let puzzle = try makeGrid(size: 4, "1000 0030 0200 0004")
        let solved = try XCTUnwrap(solve(puzzle, rules: .fourByFour))
        assertValidSolution(solved, of: puzzle, rules: .fourByFour)
        XCTAssertEqual(solutionCount(puzzle, rules: .fourByFour, limit: 2), 1)
    }

    func testSolvesEmptyFourByFour() throws {
        let empty = Grid(rules: .fourByFour)
        let solved = try XCTUnwrap(solve(empty, rules: .fourByFour))
        assertValidSolution(solved, of: empty, rules: .fourByFour)
    }

    func testFiveByFiveIsLatinSquareWithoutBoxes() throws {
        let puzzle = try makeGrid(size: 5, "12000 00000 00000 00000 00001")
        let solved = try XCTUnwrap(solve(puzzle, rules: .fiveByFive))
        assertValidSolution(solved, of: puzzle, rules: .fiveByFive)
        // 5×5 没有宫，同一个 2×2 区域里允许出现重复数字，只检查行列
        XCTAssertTrue(conflicts(in: solved, rules: .fiveByFive).isEmpty)
    }

    func testFiveByFiveCountsLatinSquares() throws {
        // 只固定第一行时解很多，这里验证计数会在 limit 处停下
        let firstRowFixed = try makeGrid(size: 5, "12345 00000 00000 00000 00000")
        XCTAssertEqual(solutionCount(firstRowFixed, rules: .fiveByFive, limit: 50), 50)
    }

    func testSolvesNineByNineEasyPuzzle() throws {
        let puzzle = try makeGrid(size: 9, Self.easyPuzzle)
        let solved = try XCTUnwrap(solve(puzzle, rules: .nineByNine))
        assertValidSolution(solved, of: puzzle, rules: .nineByNine)
        XCTAssertEqual(solved.cells, try makeGrid(size: 9, Self.easySolution).cells)
    }

    func testCompleteValidGridReturnsItself() throws {
        let complete = try makeGrid(size: 9, Self.easySolution)
        XCTAssertEqual(solve(complete, rules: .nineByNine), complete)
        XCTAssertEqual(solutionCount(complete, rules: .nineByNine, limit: 2), 1)
    }

    // MARK: - 无解

    func testContradictoryGivensHaveNoSolution() throws {
        let puzzle = try makeGrid(size: 4, "1100 0000 0000 0000")
        XCTAssertNil(solve(puzzle, rules: .fourByFour))
        XCTAssertEqual(solutionCount(puzzle, rules: .fourByFour, limit: 2), 0)
    }

    func testCompleteButInvalidGridHasNoSolution() throws {
        var broken = try makeGrid(size: 9, Self.easySolution)
        broken[row: 0, column: 0] = broken[row: 0, column: 1]
        XCTAssertNil(solve(broken, rules: .nineByNine))
        XCTAssertEqual(solutionCount(broken, rules: .nineByNine, limit: 2), 0)
    }

    func testNoConflictButUnsolvablePuzzle() throws {
        // 第一行的 (0,0) 只能填 1，但同列的 (1,0) 已经是 1；已有数字之间没有冲突
        let puzzle = try makeGrid(size: 4, "0234 1000 0000 0000")
        XCTAssertTrue(conflicts(in: puzzle, rules: .fourByFour).isEmpty)
        XCTAssertNil(solve(puzzle, rules: .fourByFour))
        XCTAssertEqual(solutionCount(puzzle, rules: .fourByFour, limit: 2), 0)
    }

    func testNineByNineUnsolvableWithoutConflict() throws {
        // 第一行 1...8 齐全，(0,8) 只能填 9；但第 9 列已经有 9，需要放在别处
        var puzzle = Grid(rules: .nineByNine)
        for column in 0 ..< 8 {
            puzzle[row: 0, column: column] = column + 1
        }
        puzzle[row: 4, column: 8] = 9
        XCTAssertTrue(conflicts(in: puzzle, rules: .nineByNine).isEmpty)
        XCTAssertNil(solve(puzzle, rules: .nineByNine))
    }

    // MARK: - 多解与 limit

    func testMultipleSolutionsStopAtLimit() throws {
        let sparse = try makeGrid(size: 4, "1000 0000 0000 0000")
        XCTAssertEqual(solutionCount(sparse, rules: .fourByFour, limit: 2), 2)
        XCTAssertEqual(solutionCount(sparse, rules: .fourByFour, limit: 5), 5)
        let solved = try XCTUnwrap(solve(sparse, rules: .fourByFour))
        assertValidSolution(solved, of: sparse, rules: .fourByFour)
    }

    func testCountStopsEarlyOnEmptyNineByNine() {
        let empty = Grid(rules: .nineByNine)
        XCTAssertEqual(solutionCount(empty, rules: .nineByNine, limit: 2), 2)
    }

    func testFourByFourTotalSolutionCountIs288() {
        let empty = Grid(rules: .fourByFour)
        XCTAssertEqual(solutionCount(empty, rules: .fourByFour, limit: 1000), 288)
    }

    func testZeroOrNegativeLimitReturnsZero() throws {
        let puzzle = try makeGrid(size: 9, Self.easyPuzzle)
        XCTAssertEqual(solutionCount(puzzle, rules: .nineByNine, limit: 0), 0)
        XCTAssertEqual(solutionCount(puzzle, rules: .nineByNine, limit: -3), 0)
    }

    func testSolveDoesNotChangeInput() throws {
        let puzzle = try makeGrid(size: 9, Self.easyPuzzle)
        let copy = puzzle
        _ = solve(puzzle, rules: .nineByNine)
        XCTAssertEqual(puzzle, copy)
    }

    // MARK: - 已知题集

    func testKnownPuzzleSetIsSolvedAndUnique() throws {
        for (name, text) in Self.knownPuzzles {
            let puzzle = try makeGrid(size: 9, text)
            let solved = try XCTUnwrap(solve(puzzle, rules: .nineByNine), name)
            assertValidSolution(solved, of: puzzle, rules: .nineByNine, message: name)
            XCTAssertEqual(solutionCount(puzzle, rules: .nineByNine, limit: 2), 1, name)
        }
    }

    // MARK: - 冲突检测

    func testConflictsEmptyOnCleanGrid() throws {
        let clean = try makeGrid(size: 9, Self.easyPuzzle)
        XCTAssertTrue(conflicts(in: clean, rules: .nineByNine).isEmpty)
        XCTAssertTrue(conflicts(in: Grid(rules: .nineByNine), rules: .nineByNine).isEmpty)
    }

    func testConflictsInRow() throws {
        let grid = try makeGrid(size: 4, "1001 0000 0000 0000")
        let expected: Set<CellIndex> = [CellIndex(row: 0, column: 0), CellIndex(row: 0, column: 3)]
        XCTAssertEqual(conflicts(in: grid, rules: .fourByFour), expected)
    }

    func testConflictsInColumn() throws {
        let grid = try makeGrid(size: 4, "2000 0000 0000 2000")
        let expected: Set<CellIndex> = [CellIndex(row: 0, column: 0), CellIndex(row: 3, column: 0)]
        XCTAssertEqual(conflicts(in: grid, rules: .fourByFour), expected)
    }

    func testConflictsInBox() throws {
        let grid = try makeGrid(size: 4, "3000 0300 0000 0000")
        let expected: Set<CellIndex> = [CellIndex(row: 0, column: 0), CellIndex(row: 1, column: 1)]
        XCTAssertEqual(conflicts(in: grid, rules: .fourByFour), expected)
    }

    func testFiveByFiveIgnoresBoxes() throws {
        // 同样的位置在 4×4 里属于同一个宫，5×5 没有宫，所以不算冲突
        let grid = try makeGrid(size: 5, "30000 03000 00000 00000 00000")
        XCTAssertTrue(conflicts(in: grid, rules: .fiveByFive).isEmpty)
    }

    func testThreeInARowAllMarked() throws {
        let grid = try makeGrid(size: 5, "11100 00000 00000 00000 00000")
        XCTAssertEqual(conflicts(in: grid, rules: .fiveByFive).count, 3)
    }

    func testCellInTwoConflictsIsReportedOnce() throws {
        let grid = try makeGrid(size: 9, "5...5.... 5........ ........." + String(repeating: ".", count: 54))
        let marked = conflicts(in: grid, rules: .nineByNine)
        let expected: Set<CellIndex> = [
            CellIndex(row: 0, column: 0), CellIndex(row: 0, column: 4), CellIndex(row: 1, column: 0),
        ]
        XCTAssertEqual(marked, expected)
    }

    // MARK: - 性能

    func testHardNineByNineSolvesUnderBudget() throws {
        let budgetMilliseconds = 50.0
        for (name, text) in Self.hardPuzzles {
            let puzzle = try makeGrid(size: 9, text)
            let median = medianMilliseconds(runs: 7) {
                _ = solve(puzzle, rules: .nineByNine)
            }
            print("solve \(name): median \(median) ms")
            // 耗时断言只在 release 下生效，debug/CI 下只打印，避免计时抖动导致误报
            #if !DEBUG
                XCTAssertLessThan(median, budgetMilliseconds, name)
            #endif
        }
    }

    // MARK: - 辅助

    private func medianMilliseconds(runs: Int, _ work: () -> Void) -> Double {
        var samples: [Double] = []
        for _ in 0 ..< runs {
            let start = ContinuousClock.now
            work()
            let elapsed = ContinuousClock.now - start
            let parts = elapsed.components
            samples.append(Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15)
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    /// 检查：尺寸对、每格已填、无冲突、题目给定数字没变。
    private func assertValidSolution(
        _ solved: Grid,
        of puzzle: Grid,
        rules: Rules,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(solved.size, rules.size, message, file: file, line: line)
        XCTAssertFalse(solved.cells.contains(Grid.emptyCell), message, file: file, line: line)
        XCTAssertTrue(conflicts(in: solved, rules: rules).isEmpty, message, file: file, line: line)
        for (index, given) in puzzle.cells.enumerated() where given != Grid.emptyCell {
            XCTAssertEqual(solved.cells[index], given, "given changed at \(index) \(message)", file: file, line: line)
        }
    }

    /// 用文本造棋盘。`0` 和 `.` 都是空格，空白会被忽略。
    private func makeGrid(size: Int, _ text: String) throws -> Grid {
        var cells: [Int] = []
        for character in text where !character.isWhitespace {
            if character == "." {
                cells.append(0)
            } else {
                cells.append(try XCTUnwrap(character.wholeNumberValue))
            }
        }
        return try Grid(size: size, cells: cells)
    }

    private static let easyPuzzle =
        "003020600 900305001 001806400 008102900 700000008 006708200 002609500 800203009 005010300"
    private static let easySolution =
        "483921657 967345821 251876493 548132976 729564138 136798245 372689514 814253769 695417382"

    private static let hardPuzzles: [(String, String)] = [
        ("inkala-2012", "8........ ..36..... .7..9.2.. .5...7... ....457.. ...1...3. ..1....68 ..85...1. .9....4.."),
        ("norvig-hard1", "85...24.. 72......9 ..4...... ...1.7..2 3.5...9.. .4....... ....8..7. .17...... ....36.4."),
    ]

    private static let knownPuzzles: [(String, String)] = [
        ("easy", easyPuzzle),
        ("inkala-2010", "1....7.9. .3..2...8 ..96..5.. ..53..9.. .1..8...2 6....4... 3......1. .4......7 ..7...3.."),
    ] + hardPuzzles
}
