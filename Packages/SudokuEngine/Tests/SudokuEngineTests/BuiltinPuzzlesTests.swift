import Foundation
@testable import SudokuEngine
import XCTest

/// 校验内置题库 BuiltinPuzzles.json 的内容。
final class BuiltinPuzzlesTests: XCTestCase {
    private let expectedEasyMediumHardCount = 30
    /// 内置专家题只收不需要试数的题，实际生成了这么多。
    private let expectedExpertCount = 30
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
        let expected: [Difficulty: Int] = [
            .easy: expectedEasyMediumHardCount,
            .medium: expectedEasyMediumHardCount,
            .hard: expectedEasyMediumHardCount,
            .expert: expectedExpertCount
        ]
        for tier in Difficulty.allCases {
            let count = entries.filter { $0.difficulty == tier }.count
            XCTAssertEqual(count, expected[tier], "tier \(tier)")
        }
    }

    func testEasyEntriesHaveEnoughGivens() throws {
        for entry in try loadEntries() where entry.difficulty == .easy {
            let givenCount = entry.givens.filter { $0 != Grid.emptyCell }.count
            XCTAssertGreaterThanOrEqual(givenCount, minimumEasyGivens, entry.id.value)
        }
    }

    func testNoBuiltinEntryNeedsTrialAndError() throws {
        for entry in try loadEntries() {
            let grid = try makePuzzleGrid(entry)
            let grade = try DifficultyGrader.grade(grid, rules: .nineByNine).get()
            XCTAssertNotEqual(grade.hardestTechnique, .trialAndError, entry.id.value)
            XCTAssertLessThan(entry.seRating, 11, entry.id.value)
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
            XCTAssertEqual(grade.difficulty, entry.difficulty, entry.id.value)
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
