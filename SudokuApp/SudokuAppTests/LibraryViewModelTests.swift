import Foundation
@testable import SudokuApp
import XCTest

/// 简单的固定种子随机数，让抽题可复现。
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

@MainActor
final class LibraryViewModelTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)

    /// 每题第 0 格填不同数字，方便从题面认出是哪一条。
    private func entry(_ name: String, _ marker: Int, _ difficulty: Difficulty,
                       _ source: PuzzleSource, age: Double) -> PuzzleBankEntry {
        let givens = [marker] + Array(repeating: 0, count: 80)
        return PuzzleBankEntry(
            id: PuzzleFingerprint(value: name), size: 9, givens: givens, difficulty: difficulty,
            score: 0, source: source, addedAt: epoch.addingTimeInterval(age)
        )
    }

    private func makeModel() -> LibraryViewModel {
        let entries = [
            entry("a", 1, .easy, .builtin, age: 3), entry("b", 2, .hard, .builtin, age: 1),
            entry("c", 3, .medium, .userUpload, age: 2), entry("d", 4, .easy, .userUpload, age: 4),
            entry("e", 5, .expert, .builtin, age: 0), entry("f", 6, .hard, .userUpload, age: 5),
        ]
        return LibraryViewModel(bank: MockPuzzleBank(entries: entries))
    }

    /// 设置筛选后返回可见题目的名字，保持断言简短。
    private func names(_ model: LibraryViewModel, difficulty: Difficulty? = nil,
                       source: PuzzleSource? = nil) -> [String] {
        model.difficultyFilter = difficulty
        model.sourceFilter = source
        return model.visibleEntries.map(\.id.value)
    }

    func testAllFiveSorts() {
        let model = makeModel()
        let expected: [PuzzleBankSort: [String]] = [
            .difficultyAscending: ["a", "d", "c", "b", "f", "e"],
            .difficultyDescending: ["e", "b", "f", "c", "a", "d"],
            .addedAtNewest: ["f", "d", "a", "c", "b", "e"],
            .addedAtOldest: ["e", "b", "c", "a", "d", "f"],
            .sourceThenDifficulty: ["a", "b", "e", "d", "c", "f"],
        ]
        XCTAssertEqual(expected.count, PuzzleBankSort.allCases.count)
        for (sort, order) in expected {
            model.sort = sort
            XCTAssertEqual(names(model), order, "\(sort)")
        }
    }

    func testFilters() {
        let model = makeModel()
        model.sort = .difficultyAscending
        XCTAssertEqual(names(model, difficulty: .hard), ["b", "f"])
        XCTAssertEqual(names(model, source: .userUpload), ["d", "c", "f"])
        XCTAssertEqual(names(model, difficulty: .hard, source: .userUpload), ["f"])
        XCTAssertTrue(names(model, difficulty: .medium, source: .builtin).isEmpty)
    }

    func testNewGamePuzzleOnlyPicksChosenDifficulty() {
        let model = makeModel()
        var generator = SeededGenerator(state: 42)
        var seen: Set<Int> = []
        for _ in 0 ..< 30 {
            seen.insert(model.newGamePuzzle(difficulty: .hard, using: &generator)?.givens.cells[0] ?? -1)
        }
        XCTAssertEqual(seen, [2, 6])
        let empty = LibraryViewModel(bank: MockPuzzleBank(entries: []))
        XCTAssertNil(empty.newGamePuzzle(difficulty: .easy, using: &generator))
    }

    func testAddRejectsUnsupportedSizeAndDuplicate() {
        var bank = MockPuzzleBank.builtin(now: epoch)
        let four = FixtureLibrary.puzzle(for: .four)
        XCTAssertEqual(bank.add(four.givens, rules: four.rules, source: .userUpload), .failure(.unsupportedSize))
        XCTAssertEqual(LibraryCopy.message(.unsupportedSize), "该尺寸暂不入库")
        let nine = FixtureLibrary.puzzle(for: .nine)
        let existing = bank.storedEntries[0]
        let result = bank.add(nine.givens, rules: nine.rules, source: .userUpload)
        XCTAssertEqual(result, .failure(.duplicate(existing: existing)))
    }
}
