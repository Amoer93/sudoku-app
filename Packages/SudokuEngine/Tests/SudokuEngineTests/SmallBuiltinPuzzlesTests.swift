import Foundation
@testable import SudokuEngine
import XCTest

/// 校验 SmallBuiltinPuzzles.json 里的 80 道小棋盘题，以及小棋盘出题、指纹、筛选。
final class SmallBuiltinPuzzlesTests: XCTestCase {
    private let allRules: [Rules] = [.fourByFour, .fiveByFive]
    /// 每个（边长，档位）允许的给定数范围，和 docs/Difficulty.md 一致。
    private let givenRanges: [Int: [Difficulty: ClosedRange<Int>]] = [
        4: [.easy: 8 ... 10, .hard: 4 ... 6],
        5: [.easy: 12 ... 14, .hard: 7 ... 9]
    ]

    func testBankHasTwentyPuzzlesPerSizeAndTier() throws {
        let entries = try PuzzleBank.loadSmallBuiltin(bundle: .module)
        XCTAssertEqual(entries.count, 80)
        XCTAssertEqual(Set(entries.map(\.id)).count, 80)
        for rules in allRules {
            for tier in [Difficulty.easy, .hard] {
                XCTAssertEqual(entries.filter { $0.size == rules.size && $0.difficulty == tier }.count, 20)
            }
        }
        for entry in entries {
            XCTAssertEqual(entry.source, .builtin)
            XCTAssertNil(entry.tierOverride)
            XCTAssertEqual(entry.givens.count, entry.size * entry.size)
        }
    }

    func testEveryEntryFollowsItsTierRules() throws {
        for entry in try PuzzleBank.loadSmallBuiltin(bundle: .module) {
            let rules = try XCTUnwrap(allRules.first { $0.size == entry.size })
            let grid = try Grid(size: entry.size, cells: entry.givens)
            XCTAssertEqual(solutionCount(grid, rules: rules, limit: 2), 1, entry.id.value)
            let range = try XCTUnwrap(givenRanges[entry.size]?[entry.difficulty])
            XCTAssertTrue(range.contains(entry.givens.filter { $0 != Grid.emptyCell }.count), entry.id.value)
            // 只靠唯一数能解完，而且重新评分的结果和文件里记的一样
            let rating = try XCTUnwrap(rateSmallBoard(grid, rules: rules), entry.id.value)
            if entry.difficulty == .easy { XCTAssertGreaterThanOrEqual(rating.minEarlyFillable, 4, entry.id.value) }
            XCTAssertEqual(gradeSmallBoard(grid, rules: rules)?.difficulty, entry.difficulty)
            XCTAssertEqual(rating.seRating, entry.seRating)
            XCTAssertEqual(rating.score, entry.score)
            XCTAssertEqual(smallFingerprint(grid, rules: rules), entry.id)
        }
    }

    func testGeneratorIsDeterministicAndValidOnSmallBoards() {
        for rules in allRules {
            var first = PuzzleRandomGenerator(seed: 7)
            var second = PuzzleRandomGenerator(seed: 7)
            let solution = PuzzleGenerator.makeSolution(rules: rules, using: &first)
            XCTAssertEqual(solution, PuzzleGenerator.makeSolution(rules: rules, using: &second))
            XCTAssertFalse(solution.cells.contains(Grid.emptyCell))
            XCTAssertTrue(conflicts(in: solution, rules: rules).isEmpty)
            let puzzle = PuzzleGenerator.makePuzzle(rules: rules, targetGivens: 0, using: &first)
            XCTAssertEqual(puzzle, PuzzleGenerator.makePuzzle(rules: rules, targetGivens: 0, using: &second))
            XCTAssertEqual(solutionCount(puzzle, rules: rules, limit: 2), 1)
        }
    }

    func testFingerprintIgnoresTransposeAndDigitRelabel() throws {
        let entries = try PuzzleBank.loadSmallBuiltin(bundle: .module)
        for rules in allRules {
            let size = rules.size
            let entry = try XCTUnwrap(entries.first { $0.size == size })
            var changedCells: [Int] = []
            for index in 0 ..< rules.cellCount {
                let value = entry.givens[(index % size) * size + index / size]
                // 转置后再把每个数字换成下一个（最大的换成 1）
                changedCells.append(value == Grid.emptyCell ? value : value % size + 1)
            }
            let changed = try Grid(size: size, cells: changedCells)
            XCTAssertNotEqual(changedCells, entry.givens)
            XCTAssertEqual(smallFingerprint(changed, rules: rules), entry.id)
            XCTAssertTrue(entry.id.value.hasPrefix("s\(size)-"))
        }
    }

    func testSizeFilterSeparatesSmallBoardsFromNineByNine() throws {
        let bank = PuzzleBank(entries: try PuzzleBank.loadBuiltin() + PuzzleBank.loadSmallBuiltin(bundle: .module))
        XCTAssertEqual(bank.entries(size: 9).count, 150)
        XCTAssertEqual(bank.entries(size: 4).count, 40)
        XCTAssertEqual(bank.entries(size: 5, difficulty: .hard).count, 20)
        XCTAssertEqual(bank.entries().count, 230)
        XCTAssertEqual(bank.randomEntry(size: 5, difficulty: .easy)?.size, 5)
        var generator = PuzzleRandomGenerator(seed: 1)
        XCTAssertEqual(bank.randomEntry(size: 4, using: &generator)?.size, 4)
    }
}
