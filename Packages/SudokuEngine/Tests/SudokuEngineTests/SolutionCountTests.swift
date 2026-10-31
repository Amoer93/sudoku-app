import SudokuEngine
import XCTest

final class SolutionCountTests: XCTestCase {
    // MARK: - 4×4

    func testFourByFourUnique() throws {
        let puzzle = try makeGrid(size: 4, "1000 0030 0200 0004")
        XCTAssertEqual(solutionCount(puzzle, rules: .fourByFour), .unique)
    }

    func testFourByFourMultiple() throws {
        let puzzle = try makeGrid(size: 4, "1000 0000 0000 0000")
        XCTAssertEqual(solutionCount(puzzle, rules: .fourByFour), .multiple)
    }

    func testFourByFourNoConflictButUnsolvable() throws {
        let puzzle = try makeGrid(size: 4, "0234 1000 0000 0000")
        XCTAssertTrue(conflicts(in: puzzle, rules: .fourByFour).isEmpty)
        XCTAssertEqual(solutionCount(puzzle, rules: .fourByFour), .none)
    }

    func testFourByFourGivenConflict() throws {
        let puzzle = try makeGrid(size: 4, "1100 0000 0000 0000")
        XCTAssertFalse(conflicts(in: puzzle, rules: .fourByFour).isEmpty)
        XCTAssertEqual(solutionCount(puzzle, rules: .fourByFour), .none)
    }

    // MARK: - 5×5

    func testFiveByFiveUnique() throws {
        let puzzle = try makeGrid(size: 5, "20301 00145 01003 00000 50214")
        XCTAssertEqual(solutionCount(puzzle, rules: .fiveByFive, limit: 2), 1)
        XCTAssertEqual(solutionCount(puzzle, rules: .fiveByFive), .unique)
    }

    func testFiveByFiveMultiple() throws {
        let puzzle = try makeGrid(size: 5, "12345 00000 00000 00000 00000")
        XCTAssertEqual(solutionCount(puzzle, rules: .fiveByFive), .multiple)
    }

    func testFiveByFiveColumnConflict() throws {
        let puzzle = try makeGrid(size: 5, "10000 00000 00000 00000 10000")
        XCTAssertFalse(conflicts(in: puzzle, rules: .fiveByFive).isEmpty)
        XCTAssertEqual(solutionCount(puzzle, rules: .fiveByFive), .none)
    }

    // MARK: - 9×9

    func testNineByNineUnique() throws {
        let puzzle = try makeGrid(size: 9, Self.easyPuzzle)
        XCTAssertEqual(solutionCount(puzzle, rules: .nineByNine), .unique)
    }

    func testNineByNineBoxConflict() throws {
        let puzzle = try makeGrid(
            size: 9,
            "500000000 050000000 000000000 " +
                "000000000 000000000 000000000 " +
                "000000000 000000000 000000000"
        )
        XCTAssertFalse(conflicts(in: puzzle, rules: .nineByNine).isEmpty)
        XCTAssertEqual(solutionCount(puzzle, rules: .nineByNine), .none)
    }

    func testNineByNineCompleteValidIsUnique() throws {
        let puzzle = try makeGrid(size: 9, Self.easySolution)
        XCTAssertEqual(solutionCount(puzzle, rules: .nineByNine), .unique)
    }

    func testNineByNineMultipleAfterRemovingGivens() throws {
        var puzzle = try makeGrid(size: 9, Self.easyPuzzle)
        for column in 0 ..< 9 {
            puzzle[row: 0, column: column] = 0
        }
        XCTAssertEqual(solutionCount(puzzle, rules: .nineByNine), .multiple)
    }

    // MARK: - 空盘

    func testEmptyBoardsAreMultiple() {
        XCTAssertEqual(solutionCount(Grid(rules: .fourByFour), rules: .fourByFour), .multiple)
        XCTAssertEqual(solutionCount(Grid(rules: .fiveByFive), rules: .fiveByFive), .multiple)
        XCTAssertEqual(solutionCount(Grid(rules: .nineByNine), rules: .nineByNine), .multiple)
    }

    // MARK: - 辅助

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
}
