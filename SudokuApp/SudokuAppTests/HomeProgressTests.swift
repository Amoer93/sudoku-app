import Foundation
@testable import SudokuApp
import SudokuEngine
import XCTest

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
        if let lastPlayed { result.recordLastPlayed(lastPlayed) }
        return result
    }

    func testTilesOnlyMarkLastPlayedOfTheirOwnDifficulty() {
        let bank = bank()
        var data = PuzzleProgressRecords()
        data.recordLastPlayed(LastPlayedRecord(id: PuzzleFingerprint(value: "a"), difficulty: .easy, playedAt: epoch))
        // 后来去玩了中等的题：简单那一格还是标着，两档各记各的
        let later = Date(timeIntervalSince1970: 60)
        data.recordLastPlayed(LastPlayedRecord(id: PuzzleFingerprint(value: "m"), difficulty: .medium, playedAt: later))
        let easyTiles = HomeProgress(entries: bank.builtinEntries(difficulty: .easy), records: data).tiles
        XCTAssertEqual(easyTiles.filter(\.isLastPlayed).map(\.entry.id.value), ["a"])
        let mediumTiles = HomeProgress(entries: bank.builtinEntries(difficulty: .medium), records: data).tiles
        XCTAssertEqual(mediumTiles.filter(\.isLastPlayed).map(\.entry.id.value), ["m"])
        XCTAssertEqual(ProgressCopy.smallBoards, "棋盘挑选")
        XCTAssertEqual(ProgressCopy.moreFeatures, "其他功能")
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
        XCTAssertEqual(ProgressCopy.tileVoiceOver(number: 12, isCompleted: false), "第 12 题，新题")
        XCTAssertEqual(ProgressCopy.tileVoiceOver(number: 12, isCompleted: true), "第 12 题，已经做完")
        XCTAssertEqual(ProgressCopy.tileVoiceOver(number: 12, isCompleted: false, isInProgress: true), "第 12 题，玩到一半")
        XCTAssertEqual(ProgressCopy.tileVoiceOver(number: 12, isCompleted: true, isInProgress: true), "第 12 题，玩到一半")
        XCTAssertEqual([ProgressCopy.resume, ProgressCopy.resumeHint], ["继续上一次", "接着上次的棋盘玩"])
        // 继续控件的朗读：去掉「上次玩的：」和「 · 」，前面加「继续上一次，」
        let resumeSpoken = ["上次玩的：困难 · 第 4 题", "上次玩的：4×4", "上次玩的：困难"].map {
            ProgressCopy.resumeVoiceOver(from: $0)
        }
        XCTAssertEqual(resumeSpoken, ["继续上一次，困难第 4 题", "继续上一次，4×4", "继续上一次，困难"])
        let restartCopy = [ProgressCopy.restartAction, ProgressCopy.restartMessage]
        XCTAssertEqual(restartCopy, ["重新开始这一题", "这一题现在的进度会被清掉，要重新开始吗？"])
        XCTAssertEqual([ProgressCopy.restartConfirm, ProgressCopy.restartCancel], ["重新开始", "先不了"])
        // 要保留的存档：题库里任何来源的题 + 两个小棋盘；题库读空时不清理
        let known = HomeProgress.knownSessionIDs(bank: bank())
        let expected = Set(["a", "b", "c", "u", "m", "fixture-4", "fixture-5"].map { PuzzleFingerprint(value: $0) })
        XCTAssertEqual(known, expected)
        XCTAssertNil(HomeProgress.knownSessionIDs(bank: PuzzleBank(entries: [])))
        // 行朗读：玩到一半优先，不会同时读「已经做完」
        let suffixes = [(true, true), (true, false), (false, false)].map {
            ProgressCopy.stateSuffix(isCompleted: $0.0, isInProgress: $0.1)
        }
        XCTAssertEqual(suffixes, ["，玩到一半", "，已经做完", ""])
        let aID = PuzzleFingerprint(value: "a")
        let tile = HomeProgress(entries: [entry("a", score: 1)], restartableIDs: [aID]).tiles[0]
        XCTAssertTrue(tile.isRestartable)
        XCTAssertFalse(tile.isInProgress)
    }

    func testInProgressTilesAndResumeTarget() {
        let firstID = PuzzleFingerprint(value: "a")
        let progress = HomeProgress(entries: bank().builtinEntries(difficulty: .easy), inProgressIDs: [firstID])
        XCTAssertEqual(progress.tiles.map(\.isInProgress), [true, false, false])
        let target = { (id: String, open: Set<PuzzleFingerprint>) in
            let fingerprint = PuzzleFingerprint(value: id)
            let record = LastPlayedRecord(id: fingerprint, difficulty: .easy, size: 9, playedAt: self.epoch)
            return HomeProgress.resumeTarget(lastPlayed: record, inProgressIDs: open, bank: self.bank())
        }
        guard case .bank(let found, let level) = target("a", [firstID]) else { return XCTFail("应该能继续") }
        XCTAssertEqual(found.id, firstID)
        XCTAssertEqual(level, .easy)
        XCTAssertNil(target("a", [])) // 没有存档，或存档是全解 / 新版本
        XCTAssertNil(target("gone", [PuzzleFingerprint(value: "gone")])) // 题已不在题库
        XCTAssertNil(HomeProgress.resumeTarget(lastPlayed: nil, inProgressIDs: [firstID], bank: bank()))
        XCTAssertEqual(target("fixture-5", [HomeProgress.fixture5]), .fixture(.five))
        XCTAssertEqual(target("fixture-4", [HomeProgress.fixture4]), .fixture(.four))
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
        XCTAssertEqual(HomeProgress(entries: []).summaryText, "这一档还没有题目，换一个难度或棋盘试试吧")
    }
}
