import Foundation
@testable import SudokuApp
import SudokuEngine
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

    /// 每题第 0 格填不同数字，方便从题面认出是哪一条；score 和 age 各不相同，排序不靠打平规则。
    private func entry(_ name: String, _ marker: Int, _ difficulty: Difficulty,
                       _ source: PuzzleSource, score: Int, age: Double) -> PuzzleBankEntry {
        let givens = [marker] + Array(repeating: 0, count: 80)
        return PuzzleBankEntry(
            id: PuzzleFingerprint(value: name), size: 9, givens: givens, difficulty: difficulty,
            seRating: 2.0, score: score, source: source, addedAt: epoch.addingTimeInterval(age)
        )
    }

    private func makeModel() -> LibraryViewModel {
        let entries = [
            entry("a", 1, .easy, .builtin, score: 10, age: 3), entry("b", 2, .hard, .builtin, score: 30, age: 1),
            entry("c", 3, .medium, .userUpload, score: 20, age: 2),
            entry("d", 4, .easy, .userUpload, score: 11, age: 4),
            entry("e", 5, .expert, .builtin, score: 40, age: 0), entry("f", 6, .hard, .userUpload, score: 31, age: 5),
        ]
        return LibraryViewModel(bank: PuzzleBank(entries: entries))
    }

    /// 设置筛选后返回可见题目的名字（排好序），避免依赖同档内的顺序。
    private func sortedNames(_ model: LibraryViewModel, difficulty: Difficulty? = nil,
                             source: PuzzleSource? = nil) -> [String] {
        model.difficultyFilter = difficulty
        model.sourceFilter = source
        return model.visibleEntries.map(\.id.value).sorted()
    }

    func testDifficultySortsAreMonotonic() {
        let model = makeModel()
        model.sort = .difficultyAscending
        let ascending = model.visibleEntries.map(\.difficulty)
        XCTAssertEqual(ascending, ascending.sorted())
        model.sort = .difficultyDescending
        let descending = model.visibleEntries.map(\.difficulty)
        XCTAssertEqual(descending, descending.sorted(by: >))
    }

    func testAddedAtSorts() {
        let model = makeModel()
        model.sort = .addedAtNewest
        XCTAssertEqual(model.visibleEntries.map(\.id.value), ["f", "d", "a", "c", "b", "e"])
        model.sort = .addedAtOldest
        XCTAssertEqual(model.visibleEntries.map(\.id.value), ["e", "b", "c", "a", "d", "f"])
    }

    func testSourceThenDifficultyPutsBuiltinFirst() {
        let model = makeModel()
        XCTAssertEqual(model.sort, .sourceThenDifficulty)
        let sources = model.visibleEntries.map(\.source)
        XCTAssertEqual(sources, [.builtin, .builtin, .builtin, .userUpload, .userUpload, .userUpload])
        let builtinDifficulties = model.visibleEntries.prefix(3).map(\.difficulty)
        XCTAssertEqual(builtinDifficulties, [.easy, .hard, .expert])
    }

    func testPickerListsAllSorts() {
        XCTAssertEqual(LibraryCopy.sorts.count, 5)
        for sort in LibraryCopy.sorts {
            XCTAssertFalse(LibraryCopy.title(sort).isEmpty)
        }
    }

    func testFilters() {
        let model = makeModel()
        XCTAssertEqual(sortedNames(model, difficulty: .hard), ["b", "f"])
        XCTAssertEqual(sortedNames(model, source: .userUpload), ["c", "d", "f"])
        XCTAssertEqual(sortedNames(model, difficulty: .hard, source: .userUpload), ["f"])
        XCTAssertTrue(sortedNames(model, difficulty: .medium, source: .builtin).isEmpty)
        XCTAssertFalse(model.isBankEmpty)
    }

    func testClearFiltersResetsBoth() {
        let model = makeModel()
        model.difficultyFilter = .hard
        model.sourceFilter = .builtin
        model.clearFilters()
        XCTAssertNil(model.difficultyFilter)
        XCTAssertNil(model.sourceFilter)
    }

    func testNewGamePuzzleOnlyPicksChosenDifficulty() {
        let model = makeModel()
        var generator = SeededGenerator(state: 42)
        var seen: Set<Int> = []
        for _ in 0 ..< 30 {
            seen.insert(model.newGamePuzzle(difficulty: .hard, using: &generator)?.givens.cells[0] ?? -1)
        }
        XCTAssertEqual(seen, [2, 6])
        XCTAssertTrue(model.hasEntries(difficulty: .hard))
    }

    func testEmptyBank() {
        let model = LibraryViewModel(bank: PuzzleBank())
        var generator = SeededGenerator(state: 7)
        XCTAssertTrue(model.isBankEmpty)
        XCTAssertFalse(model.hasEntries(difficulty: .easy))
        XCTAssertNil(model.newGamePuzzle(difficulty: .easy, using: &generator))
    }

    func testOpenPuzzleTogglesIsOpening() async {
        let model = makeModel()
        let target = model.visibleEntries[0]
        XCTAssertFalse(model.isOpening)
        let puzzle = await model.openPuzzle(for: target)
        XCTAssertNotNil(puzzle)
        XCTAssertFalse(model.isOpening)
        XCTAssertNil(model.openingEntryID)
    }

    func testEmptyStateCopy() {
        XCTAssertEqual(LibraryCopy.emptyBankTitle, "题库暂无题目")
        XCTAssertEqual(LibraryCopy.emptyBankHint, "可以在首页用「拍照导入」添加题目")
        XCTAssertEqual(LibraryCopy.emptyList, "没有符合条件的题目")
        XCTAssertEqual(LibraryCopy.clearFilters, "清除筛选")
        XCTAssertEqual(LibraryCopy.difficultyFallback, "该难度暂无题库题目，将使用内置示例题")
    }
}
