import Foundation
@testable import SudokuEngine
import XCTest

/// 确定性随机数生成器。
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

final class PuzzleBankTests: XCTestCase {
    func testAddSuccess() throws {
        let grid = makeGrid(difficultyEasyPuzzle)
        var bank = PuzzleBank()
        guard case .success(let entry) = bank.add(grid, rules: .nineByNine) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(entry.size, 9)
        XCTAssertEqual(entry.givens, grid.cells)
        XCTAssertEqual(entry.source, .userUpload)
        let grade = try DifficultyGrader.grade(grid, rules: .nineByNine).get()
        XCTAssertEqual(entry.difficulty, grade.difficulty)
        XCTAssertEqual(entry.seRating, grade.seRating)
        XCTAssertEqual(entry.score, grade.score)
    }

    func testDuplicateReturnsExistingEntry() {
        let original = makeGrid(difficultyEasyPuzzle)
        var bank = PuzzleBank()
        _ = bank.add(original, rules: .nineByNine)
        let transformed = makeGrid(relabel(difficultyEasyPuzzle))
        guard case .failure(.duplicate(let existing)) = bank.add(transformed, rules: .nineByNine) else {
            return XCTFail("expected duplicate")
        }
        XCTAssertEqual(existing.id, bank.entries[0].id)
    }

    func testUnsupportedSize() {
        var bank = PuzzleBank()
        XCTAssertEqual(bank.add(Grid(rules: .fourByFour), rules: .fourByFour), .failure(.unsupportedSize))
        XCTAssertEqual(bank.add(Grid(rules: .fiveByFive), rules: .fiveByFive), .failure(.unsupportedSize))
    }

    func testUngradableNoSolution() throws {
        var cells = difficultyEasyPuzzle.compactMap { character -> Int? in
            if character == "0" { return 0 }
            return character.wholeNumberValue
        }
        cells[0] = 1
        cells[1] = 1
        var bank = PuzzleBank()
        let grid = try Grid(size: 9, cells: cells)
        XCTAssertEqual(bank.add(grid, rules: .nineByNine), .failure(.ungradable(.noSolution)))
    }

    func testUngradableMultipleSolutions() {
        var grid = makeGrid(difficultyEasyPuzzle)
        for column in 0 ..< 9 { grid[row: 0, column: column] = 0 }
        var bank = PuzzleBank()
        XCTAssertEqual(bank.add(grid, rules: .nineByNine), .failure(.ungradable(.multipleSolutions)))
    }

    func testFiltersAndSorts() {
        let early = Date(timeIntervalSince1970: 1)
        let late = Date(timeIntervalSince1970: 2)
        let entries = [
            entry(id: "a", difficulty: .easy, score: 10, source: .builtin, addedAt: early),
            entry(id: "b", difficulty: .hard, score: 30, source: .builtin, addedAt: late),
            entry(id: "c", difficulty: .easy, score: 20, source: .userUpload, addedAt: early),
            entry(id: "d", difficulty: .medium, score: 15, source: .userUpload, addedAt: late),
            entry(id: "e", difficulty: .expert, score: 50, source: .userUpload, addedAt: late),
        ]
        let bank = PuzzleBank(entries: entries)
        XCTAssertEqual(bank.entries(difficulty: .easy).map(\.id.value), ["a", "c"])
        XCTAssertEqual(bank.entries(source: .builtin).map(\.id.value), ["a", "b"])
        XCTAssertEqual(bank.entries().count, 5)
        XCTAssertEqual(bank.entries(sort: .difficultyAscending).map(\.id.value), ["a", "c", "d", "b", "e"])
        XCTAssertEqual(bank.entries(sort: .difficultyDescending).map(\.id.value), ["e", "b", "d", "c", "a"])
        XCTAssertEqual(bank.entries(sort: .addedAtNewest).map(\.id.value), ["b", "d", "e", "a", "c"])
        XCTAssertEqual(bank.entries(sort: .addedAtOldest).map(\.id.value), ["a", "c", "b", "d", "e"])
        XCTAssertEqual(bank.entries(sort: .sourceThenDifficulty).map(\.id.value), ["a", "b", "c", "d", "e"])
    }

    func testRandomEntryDeterministic() {
        let entries = (0 ..< 5).map {
            entry(id: "\($0)", difficulty: .easy, score: $0, source: .userUpload, addedAt: Date())
        }
        let bank = PuzzleBank(entries: entries)
        var rng1 = SplitMix64(seed: 42)
        let first = bank.randomEntry(using: &rng1)
        var rng2 = SplitMix64(seed: 42)
        XCTAssertEqual(first?.id, bank.randomEntry(using: &rng2)?.id)
        var rng3 = SplitMix64(seed: 1)
        XCTAssertNil(PuzzleBank().randomEntry(difficulty: .easy, using: &rng3))
    }

    func testPersistenceRoundTrip() throws {
        let user = entry(id: "user1", difficulty: .easy, score: 5, source: .userUpload, addedAt: Date())
        let builtin = entry(id: "builtin1", difficulty: .medium, score: 10, source: .builtin, addedAt: Date())
        let duplicate = entry(id: "user1", difficulty: .hard, score: 20, source: .userUpload, addedAt: Date())
        let bank = PuzzleBank(entries: [user, builtin, duplicate])
        let data = try bank.userEntriesData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode([PuzzleBankEntry].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertTrue(decoded.allSatisfy { $0.source == .userUpload })
        let restored = try PuzzleBank.load(builtinBundle: .module, userData: data)
        XCTAssertEqual(restored.entries(source: .userUpload).map(\.id.value), ["user1"])
        // 用户数据里的 builtin 条目不会被带入；内置题库来自资源文件
        XCTAssertFalse(restored.entries(source: .builtin).contains { $0.id.value == "builtin1" })
        XCTAssertEqual(restored.entries(source: .builtin).count, try PuzzleBank.loadBuiltin().count)
    }

    func testPersistencePreservesSubsecondAddedAt() throws {
        let original = entry(
            id: "subsecond",
            difficulty: .medium,
            score: 15,
            source: .userUpload,
            addedAt: Date(timeIntervalSince1970: 1_234_567.891)
        )
        let bank = PuzzleBank(entries: [original])
        let data = try bank.userEntriesData()
        let restored = try PuzzleBank.load(builtinBundle: .module, userData: data)
        XCTAssertEqual(restored.entries(source: .userUpload).first, original)
    }

    func testLoadBuiltin() throws {
        let builtin = try PuzzleBank.loadBuiltin()
        // 简单、中等、困难各 30 题；专家只收不需要试数的题，实际也是 30 题
        let expectedExpertCount = 30
        XCTAssertEqual(builtin.filter { $0.difficulty == .easy }.count, 30)
        XCTAssertEqual(builtin.filter { $0.difficulty == .medium }.count, 30)
        XCTAssertEqual(builtin.filter { $0.difficulty == .hard }.count, 30)
        XCTAssertEqual(builtin.filter { $0.difficulty == .expert }.count, expectedExpertCount)
        XCTAssertEqual(builtin.count, 90 + expectedExpertCount)
        XCTAssertTrue(builtin.allSatisfy { $0.source == .builtin })
        XCTAssertTrue(builtin.allSatisfy { $0.size == 9 })
    }

    func testUserEntryWithBuiltinFingerprintIsDropped() throws {
        let builtin = try PuzzleBank.loadBuiltin()
        let realBuiltin = try XCTUnwrap(builtin.first)
        let clash = PuzzleBankEntry(
            id: realBuiltin.id,
            size: 9,
            givens: realBuiltin.givens,
            difficulty: .hard,
            seRating: 9,
            score: 99,
            source: .userUpload,
            addedAt: Date(timeIntervalSince1970: 5)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode([clash])
        let bank = try PuzzleBank.load(builtinBundle: .module, userData: data)
        XCTAssertEqual(bank.entries.count, builtin.count)
        XCTAssertTrue(bank.entries(source: .userUpload).isEmpty)
        let kept = try XCTUnwrap(bank.entries.first { $0.id == realBuiltin.id })
        XCTAssertEqual(kept, realBuiltin)
        XCTAssertEqual(kept.source, .builtin)
    }

    func testUserEntriesDataExcludesBuiltinWithRealBank() throws {
        var bank = try PuzzleBank.load(builtinBundle: .module, userData: nil)
        let builtinCount = bank.entries.count
        guard case .success(let added) = bank.add(makeGrid(difficultyEasyPuzzle), rules: .nineByNine) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(bank.entries.count, builtinCount + 1)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode([PuzzleBankEntry].self, from: bank.userEntriesData())
        XCTAssertEqual(decoded.map(\.id), [added.id])
        XCTAssertTrue(decoded.allSatisfy { $0.source == .userUpload })
    }
}

private func relabel(_ puzzle: String) -> String {
    String(puzzle.map { character in
        guard let digit = character.wholeNumberValue, digit != 0 else { return character }
        return Character(String(digit == 9 ? 1 : digit + 1))
    })
}

private func entry(
    id: String,
    difficulty: Difficulty,
    score: Int,
    source: PuzzleSource,
    addedAt: Date
) -> PuzzleBankEntry {
    PuzzleBankEntry(
        id: PuzzleFingerprint(value: id),
        size: 9,
        givens: [],
        difficulty: difficulty,
        seRating: Double(difficulty.rawValue),
        score: score,
        source: source,
        addedAt: addedAt
    )
}
