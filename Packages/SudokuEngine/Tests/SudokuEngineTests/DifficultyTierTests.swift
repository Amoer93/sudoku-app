import SudokuEngine
import XCTest

/// 各档代表题：题目由本项目生成器（固定种子）产生，SE 值和档位按本评级器锁定。
final class DifficultyTierTests: XCTestCase {
    func testPointingPuzzleIsMedium() throws {
        try assertGrade("501080000030000000000010007020050780085300090600000003010600800050001070900020064",
                        se: 2.6, difficulty: .medium, hardest: .pointing)
    }

    func testXWingPuzzleIsMedium() throws {
        try assertGrade("100007000000206308007000200041000709020008000000600050000900000000080001304000600",
                        se: 3.2, difficulty: .medium, hardest: .xWing)
    }

    func testNakedTriplePuzzleIsHard() throws {
        try assertGrade("600028010340060500000000600090000030000805070000600480052000300000000701003010000",
                        se: 3.6, difficulty: .hard, hardest: .nakedTriple)
    }

    func testXYWingPuzzleIsHard() throws {
        try assertGrade("703000008080002000006703500800010040090020080060900023030400010450009000000000000",
                        se: 4.2, difficulty: .hard, hardest: .xyWing)
    }

    func testSimpleColoringPuzzleIsExpert() throws {
        try assertGrade("000451000000006007005000060100500200300040009094000800000000043040390602700800000",
                        se: 6.5, difficulty: .expert, hardest: .simpleColoring)
    }

    private func assertGrade(
        _ text: String, se: Double, difficulty: Difficulty, hardest: Technique,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let grid = try Grid(size: 9, cells: text.compactMap(\.wholeNumberValue))
        let result = try DifficultyGrader.grade(grid, rules: .nineByNine).get()
        XCTAssertEqual(result.seRating, se, file: file, line: line)
        XCTAssertEqual(result.difficulty, difficulty, file: file, line: line)
        XCTAssertEqual(result.hardestTechnique, hardest, file: file, line: line)
        XCTAssertEqual(result.techniqueCounts[.trialAndError, default: 0], 0, file: file, line: line)
    }
}
