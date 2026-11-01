import Foundation
@testable import SudokuEngine
import XCTest

/// 校验内置题库 BuiltinPuzzles.json 的内容。
final class BuiltinPuzzlesTests: XCTestCase {
    private let expectedPerTier = 30

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

    func testEveryTierHasEnoughPuzzles() throws {
        let entries = try loadEntries()
        for tier in Difficulty.allCases {
            let count = entries.filter { $0.difficulty == tier }.count
            XCTAssertGreaterThanOrEqual(count, expectedPerTier, "tier \(tier)")
        }
    }

    func testFingerprintsAreUniqueAndMatchIds() throws {
        let entries = try loadEntries()
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        for entry in entries {
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
