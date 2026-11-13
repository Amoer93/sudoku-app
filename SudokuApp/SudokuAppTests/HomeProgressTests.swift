import Foundation
@testable import SudokuApp
import SudokuEngine
import XCTest

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

final class HomeProgressTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)

    private func entry(_ name: String, score: Int, source: PuzzleSource = .builtin,
                       difficulty: Difficulty = .easy) -> PuzzleBankEntry {
        PuzzleBankEntry(
            id: PuzzleFingerprint(value: name), size: 9, givens: [Int](repeating: 0, count: 81),
            difficulty: difficulty, seRating: 1.0, score: score, source: source, addedAt: epoch
        )
    }

    private func records(done: [String], lastPlayed: LastPlayedRecord? = nil) -> PuzzleProgressRecords {
        var result = PuzzleProgressRecords()
        result.completed = done.map { CompletedRecord(id: PuzzleFingerprint(value: $0), completedAt: epoch) }
        result.lastPlayed = lastPlayed
        return result
    }

    private func bank() -> PuzzleBank {
        PuzzleBank(entries: [
            entry("c", score: 30), entry("a", score: 10), entry("b", score: 20),
            entry("u", score: 5, source: .userUpload), entry("m", score: 1, difficulty: .medium),
        ])
    }

    // MARK: - 数量

    func testTotalUsesBuiltinListOnly() {
        let list = bank().builtinEntries(difficulty: .easy)
        let expected = bank().entries(difficulty: .easy, source: .builtin, sort: .difficultyAscending)
        XCTAssertEqual(list.count, expected.count)
        XCTAssertFalse(list.contains { $0.source == .userUpload })
        XCTAssertEqual(HomeProgress(entries: list).total, list.count)
    }

    func testDoneIgnoresOutsideIDsAndRepeats() {
        let list = bank().builtinEntries(difficulty: .easy)
        var data = records(done: ["a", "u", "zzz"])
        data.completed[0].completionCount = 3
        let progress = HomeProgress(entries: list, records: data)
        XCTAssertEqual(progress.doneCount, 1)
        XCTAssertEqual(progress.totalCompletions, 5)
    }

    func testFractionIsZeroForEmptyList() {
        XCTAssertEqual(HomeProgress(entries: []).fraction, 0)
    }

    // MARK: - 格子

    func testTilesAreNumberedInAscendingOrderWithFlags() {
        let list = bank().builtinEntries(difficulty: .easy)
        let first = list[0].id
        let last = LastPlayedRecord(id: first, difficulty: .easy, playedAt: epoch)
        let second = list[1].id
        let data = records(done: [first.value, second.value], lastPlayed: last)
        let tiles = HomeProgress(entries: list, records: data).tiles
        XCTAssertEqual(tiles.map(\.number), Array(1 ... list.count))
        XCTAssertEqual(tiles.map(\.entry.id), list.map(\.id))
        XCTAssertTrue(tiles[0].isCompleted && tiles[0].isLastPlayed)
        XCTAssertTrue(tiles[1].isCompleted && !tiles[1].isLastPlayed)
        XCTAssertTrue(tiles.dropFirst(2).allSatisfy { !$0.isCompleted && !$0.isLastPlayed })
    }

    // MARK: - 随机

    func testRandomNeverPicksDoneWhenFreshExists() {
        let list = bank().builtinEntries(difficulty: .easy)
        let doneID = list[0].id
        let progress = HomeProgress(entries: list, records: records(done: [doneID.value]))
        var generator = SeededGenerator(state: 7)
        for _ in 0 ..< 50 {
            let picked = progress.randomEntry(using: &generator)
            XCTAssertNotNil(picked)
            XCTAssertNotEqual(picked?.id, doneID)
        }
    }

    func testRandomStillPicksWhenAllDone() {
        let list = bank().builtinEntries(difficulty: .easy)
        let progress = HomeProgress(entries: list, records: records(done: list.map(\.id.value)))
        var generator = SeededGenerator(state: 3)
        let picked = progress.randomEntry(using: &generator)
        XCTAssertTrue(list.contains { $0.id == picked?.id })
    }

    func testRandomIsNilWhenNoEntries() {
        var generator = SeededGenerator(state: 1)
        XCTAssertNil(HomeProgress(entries: []).randomEntry(using: &generator))
    }

    // MARK: - 上次玩的

    func testLastPlayedTextForBankFixtureAndNone() {
        let bank = bank()
        let list = bank.builtinEntries(difficulty: .easy)
        let bankRecord = LastPlayedRecord(id: list[1].id, difficulty: .easy, playedAt: epoch)
        XCTAssertEqual(HomeProgress.lastPlayedText(bankRecord, bank: bank), "上次玩的：简单 · 第 2 题")
        let missing = LastPlayedRecord(id: PuzzleFingerprint(value: "gone"), difficulty: .hard, playedAt: epoch)
        XCTAssertEqual(HomeProgress.lastPlayedText(missing, bank: bank), "上次玩的：困难")
        let four = LastPlayedRecord(id: HomeProgress.fixture4, size: 4, playedAt: epoch)
        XCTAssertEqual(HomeProgress.lastPlayedText(four, bank: bank), "上次玩的：4×4")
        let five = LastPlayedRecord(id: HomeProgress.fixture5, size: 5, playedAt: epoch)
        XCTAssertEqual(HomeProgress.lastPlayedText(five, bank: bank), "上次玩的：5×5")
        XCTAssertEqual(HomeProgress.lastPlayedText(nil, bank: bank), "还没玩过，先选一道题吧")
    }

    // MARK: - 文案

    func testCopyStrings() {
        XCTAssertEqual(ProgressCopy.progress(done: 7, total: 30), "已经做完 7 道，一共 30 道")
        XCTAssertEqual(ProgressCopy.progressVoiceOver(done: 7, total: 30), "这一档做完了 7 道，一共 30 道")
        XCTAssertEqual(ProgressCopy.cumulative(12), "一共做完了 12 道题，真棒！")
        XCTAssertEqual(ProgressCopy.random, "随机来一题")
        XCTAssertEqual(ProgressCopy.tileVoiceOver(number: 12, isCompleted: false), "第 12 题，新题")
        XCTAssertEqual(ProgressCopy.tileVoiceOver(number: 12, isCompleted: true), "第 12 题，已经做完")
    }

    func testRouteKeepsEntryAndPuzzle() {
        let puzzle = FixtureLibrary.puzzle(for: .nine)
        let route = PlayRoute.making(preset: .nine, entry: entry("a", score: 1), puzzle: puzzle)
        XCTAssertNotNil(route?.entry)
        XCTAssertNotNil(route?.puzzle)
    }

    func testRouteIsNilWhenEntryHasNoPuzzle() {
        XCTAssertNil(PlayRoute.making(preset: .nine, entry: entry("a", score: 1), puzzle: nil))
    }

    func testRouteStillOpensFixtureWhenBothNil() {
        let route = PlayRoute.making(preset: .four, entry: nil, puzzle: nil)
        XCTAssertNotNil(route)
        XCTAssertNil(route?.entry)
    }

    func testSummaryTextCoversZeroAndAllDone() {
        let list = bank().builtinEntries(difficulty: .easy)
        XCTAssertEqual(HomeProgress(entries: list).summaryText, ProgressCopy.zeroDone)
        let all = HomeProgress(entries: list, records: records(done: list.map(\.id.value)))
        XCTAssertEqual(all.summaryText, ProgressCopy.allDone)
        XCTAssertEqual(HomeProgress(entries: []).summaryText, ProgressCopy.emptyDifficulty)
    }
}
