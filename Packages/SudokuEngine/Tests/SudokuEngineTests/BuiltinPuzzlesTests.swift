import Foundation
@testable import SudokuEngine
import XCTest

/// 校验内置题库 BuiltinPuzzles.json 的内容。
final class BuiltinPuzzlesTests: XCTestCase {
    private let expectedTierCounts: [Difficulty: Int] = [.easy: 30, .medium: 30, .hard: 60, .expert: 30]
    private let overrideSERating = 6.5
    private let minimumEasyGivens = 30

    private func loadEntries() throws -> [PuzzleBankEntry] {
        try PuzzleBank.loadBuiltin(bundle: .module)
    }

    private func makePuzzleGrid(_ entry: PuzzleBankEntry) throws -> Grid {
        try Grid(size: entry.size, cells: entry.givens)
    }

    func testBankLoadsWithBuiltinEntriesOnly() throws {
        let bank = try PuzzleBank.load(builtinBundle: .module, userData: nil)
        XCTAssertEqual(bank.entries.count, try loadEntries().count)
        for entry in bank.entries {
            XCTAssertEqual(entry.source, .builtin)
            XCTAssertEqual(entry.size, 9)
            XCTAssertEqual(entry.givens.count, 81)
        }
    }

    func testTierCountsAreExact() throws {
        let entries = try loadEntries()
        for tier in Difficulty.allCases {
            let count = entries.filter { $0.difficulty == tier }.count
            XCTAssertEqual(count, expectedTierCounts[tier], "tier \(tier)")
        }
        XCTAssertEqual(entries.filter { $0.tierOverride != nil }.count, 30)
    }

    func testEasyEntriesHaveEnoughGivens() throws {
        for entry in try loadEntries() where entry.difficulty == .easy {
            let givenCount = entry.givens.filter { $0 != Grid.emptyCell }.count
            XCTAssertGreaterThanOrEqual(givenCount, minimumEasyGivens, entry.id.value)
        }
    }

    func testExpertEntriesNeedTrialAndError() throws {
        for entry in try loadEntries() where entry.difficulty == .expert {
            let grade = try DifficultyGrader.grade(makePuzzleGrid(entry), rules: .nineByNine).get()
            XCTAssertEqual(grade.hardestTechnique, .trialAndError, entry.id.value)
            XCTAssertNil(entry.tierOverride, entry.id.value)
        }
    }

    func testFingerprintsAreUniqueAndMatchIds() throws {
        let entries = try loadEntries()
        // 唯一性检查对所有条目都做，因为很便宜
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        // 重算指纹较慢：Debug 下只抽样（每 10 个取 1 个），Release 下全查
        #if DEBUG
            let step = 10
        #else
            let step = 1
        #endif
        for index in stride(from: 0, to: entries.count, by: step) {
            let entry = entries[index]
            let grid = try makePuzzleGrid(entry)
            XCTAssertEqual(PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine), entry.id)
        }
    }

    func testEveryEntryHasUniqueSolution() throws {
        for entry in try loadEntries() {
            let grid = try makePuzzleGrid(entry)
            XCTAssertEqual(solutionKind(grid, rules: .nineByNine), .unique, entry.id.value)
        }
    }

    func testRegradingMatchesStoredValues() throws {
        for entry in try loadEntries() {
            let grid = try makePuzzleGrid(entry)
            let grade = try DifficultyGrader.grade(grid, rules: .nineByNine).get()
            if let override = entry.tierOverride {
                // 被指定档位的题：评分器仍判专家（SE 6.5），入库档位是覆盖值
                XCTAssertEqual(override, .hard, entry.id.value)
                XCTAssertEqual(entry.difficulty, override, entry.id.value)
                XCTAssertEqual(grade.difficulty, .expert, entry.id.value)
                XCTAssertEqual(grade.seRating, overrideSERating, entry.id.value)
            } else {
                XCTAssertEqual(grade.difficulty, entry.difficulty, entry.id.value)
            }
            XCTAssertEqual(grade.seRating, entry.seRating, entry.id.value)
            XCTAssertEqual(grade.score, entry.score, entry.id.value)
        }
    }

    func testGeneratorIsDeterministic() {
        var first = PuzzleRandomGenerator(seed: 42)
        var second = PuzzleRandomGenerator(seed: 42)
        let puzzleA = PuzzleGenerator.makePuzzle(targetGivens: 36, using: &first)
        let puzzleB = PuzzleGenerator.makePuzzle(targetGivens: 36, using: &second)
        XCTAssertEqual(puzzleA, puzzleB)
        XCTAssertEqual(solutionKind(puzzleA, rules: .nineByNine), .unique)
        var other = PuzzleRandomGenerator(seed: 43)
        XCTAssertNotEqual(puzzleA, PuzzleGenerator.makePuzzle(targetGivens: 36, using: &other))
    }
}
