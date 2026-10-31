import SudokuEngine
@testable import SudokuEngine
import XCTest

final class DifficultyGraderTests: XCTestCase {
    // MARK: - grade() 入口

    func testGradeNoSolution() throws {
        let grid = makeGrid("110000000000000000000000000000000000000000000000000000000000000000000000000000000")
        let result = DifficultyGrader.grade(grid, rules: .nineByNine)
        XCTAssertEqual(result, .failure(.noSolution))
    }

    func testGradeMultipleSolutions() throws {
        let grid = Grid(rules: .nineByNine)
        let result = DifficultyGrader.grade(grid, rules: .nineByNine)
        XCTAssertEqual(result, .failure(.multipleSolutions))
    }

    func testGradeSolvedGridIsEasyWithZeroScore() throws {
        let grid = makeGrid(difficultySolutionString)
        let result = try XCTUnwrap(DifficultyGrader.grade(grid, rules: .nineByNine).get())
        XCTAssertEqual(result.difficulty, Difficulty.easy)
        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.seRating, 0)
        XCTAssertEqual(result.hardestTechnique, Technique.nakedSingle)
        XCTAssertTrue(result.techniqueCounts.isEmpty)
    }

    func testGradeEasyPuzzle() throws {
        let grid = makeGrid(difficultyEasyPuzzle)
        let result = try XCTUnwrap(DifficultyGrader.grade(grid, rules: .nineByNine).get())
        XCTAssertEqual(result.difficulty, Difficulty.easy)
        XCTAssertLessThanOrEqual(result.seRating, 2.3)
        XCTAssertGreaterThan(result.techniqueCounts.values.reduce(0, +), 0)
    }

    func testGradeHardPuzzleIsExpert() throws {
        let grid = makeGrid(difficultyHardPuzzle)
        let result = try XCTUnwrap(DifficultyGrader.grade(grid, rules: .nineByNine).get())
        XCTAssertEqual(result.difficulty, Difficulty.expert)
        XCTAssertGreaterThan(
            result.techniqueCounts[Technique.trialAndError, default: 0]
                + result.techniqueCounts[Technique.chain, default: 0],
            0
        )
    }

    func testScoreMonotoneWithCounts() throws {
        let easy = try XCTUnwrap(DifficultyGrader.grade(makeGrid(difficultyEasyPuzzle), rules: .nineByNine).get())
        let hard = try XCTUnwrap(DifficultyGrader.grade(makeGrid(difficultyHardPuzzle), rules: .nineByNine).get())
        XCTAssertGreaterThan(hard.score, easy.score)
    }

    func testGradeResultCodableRoundTrip() throws {
        let original = try XCTUnwrap(DifficultyGrader.grade(makeGrid(difficultyEasyPuzzle), rules: .nineByNine).get())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GradeResult.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testHardPuzzleSERatingIsEleven() throws {
        let grid = makeGrid(difficultyHardPuzzle)
        let result = try XCTUnwrap(DifficultyGrader.grade(grid, rules: .nineByNine).get())
        XCTAssertEqual(result.seRating, 11.0)
    }
}
