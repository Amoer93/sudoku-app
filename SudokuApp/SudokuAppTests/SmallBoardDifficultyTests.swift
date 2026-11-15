import Foundation
@testable import SudokuApp
import SudokuEngine
import XCTest

/// 只实现旧的两个方法的替身，用来测带尺寸方法的默认实现。
private struct OldStyleBank: PuzzleBankProviding {
    let all: [PuzzleBankEntry]

    func entries(difficulty: Difficulty?, source: PuzzleSource?, sort: PuzzleSort) -> [PuzzleBankEntry] {
        all.filter { difficulty == nil || $0.difficulty == difficulty }
    }

    func randomEntry<G: RandomNumberGenerator>(
        difficulty: Difficulty?, source: PuzzleSource?, using generator: inout G
    ) -> PuzzleBankEntry? {
        entries(difficulty: difficulty, source: source, sort: .difficultyAscending).randomElement(using: &generator)
    }
}

/// 小棋盘题库：按尺寸取题、档位切换、「上次玩的」按尺寸和难度记。
@MainActor
final class SmallBoardDifficultyTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)

    private func fingerprint(_ text: String) -> PuzzleFingerprint { PuzzleFingerprint(value: text) }

    private func entry(_ name: String, size: Int, _ difficulty: Difficulty = .easy) -> PuzzleBankEntry {
        PuzzleBankEntry(
            id: fingerprint(name), size: size, givens: [Int](repeating: 0, count: size * size),
            difficulty: difficulty, seRating: 1.0, score: 1, source: .builtin, addedAt: epoch
        )
    }

    private var mixedEntries: [PuzzleBankEntry] {
        [entry("n1", size: 9), entry("f1", size: 4), entry("f2", size: 4, .hard), entry("v1", size: 5)]
    }

    private func record(_ name: String, _ difficulty: Difficulty?, size: Int?) -> LastPlayedRecord {
        LastPlayedRecord(id: fingerprint(name), difficulty: difficulty, size: size, playedAt: epoch)
    }

    // MARK: - 按尺寸取题、抽题

    func testEntriesAndDrawsStayInsideOneSize() {
        let bank = PuzzleBank(entries: mixedEntries)
        XCTAssertEqual(bank.builtinEntries(difficulty: .easy, size: 4).map(\.id.value), ["f1"])
        XCTAssertEqual(bank.builtinEntries(difficulty: .easy, size: 5).map(\.id.value), ["v1"])
        XCTAssertEqual(bank.builtinEntries(difficulty: .easy).map(\.id.value), ["n1"]) // 不传尺寸就是 9×9

        var generator = SystemRandomNumberGenerator()
        let oldStyle = OldStyleBank(all: mixedEntries)
        XCTAssertEqual(oldStyle.builtinEntries(difficulty: .hard, size: 4).map(\.id.value), ["f2"])
        let model = LibraryViewModel(bank: bank)
        for _ in 0 ..< 20 {
            let drawn = oldStyle.randomEntry(size: 4, difficulty: nil, source: nil, using: &generator)
            XCTAssertEqual(drawn?.size, 4)
            let puzzle = model.newGamePuzzle(size: 4, difficulty: .easy, using: &generator)
            XCTAssertEqual(puzzle?.rules, .fourByFour)
            XCTAssertEqual(puzzle?.givens.cells.count, 16)
        }
        XCTAssertNil(model.newGamePuzzle(size: 5, difficulty: .hard, using: &generator))
        XCTAssertEqual(LibraryViewModel.makePuzzle(from: entry("v1", size: 5)).rules, .fiveByFive)
        XCTAssertEqual(LibraryViewModel.makePuzzle(from: entry("n1", size: 9)).rules, .nineByNine)
    }

    func testRealSmallBuiltinIsMergedOnlyForHome() throws {
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("small-board-tests-\(UUID().uuidString)/user-entries.json")
        let plain = PuzzleBankStore(fileURL: missingFile).load()
        let merged = plain.mergingSmallBuiltin()
        // 题库页那一份不带小棋盘题
        XCTAssertTrue(plain.entries(size: 4).isEmpty && plain.entries(size: 5).isEmpty)
        for size in [4, 5] {
            for difficulty in [Difficulty.easy, .hard] {
                let list = merged.builtinEntries(difficulty: difficulty, size: size)
                XCTAssertEqual(list.count, 20)
                XCTAssertTrue(list.allSatisfy { $0.size == size && $0.difficulty == difficulty })
            }
            XCTAssertTrue(merged.builtinEntries(difficulty: .medium, size: size).isEmpty)
        }
        XCTAssertTrue(merged.builtinEntries(difficulty: .easy).allSatisfy { $0.size == 9 })
        // 小棋盘题的存档不会被当成孤儿
        let small = try PuzzleBank.loadSmallBuiltin()
        let known = try XCTUnwrap(HomeProgress.knownSessionIDs(bank: merged))
        XCTAssertTrue(known.isSuperset(of: small.map(\.id)))

        let second = merged.builtinEntries(difficulty: .easy, size: 4)[1]
        let puzzle = LibraryViewModel.makePuzzle(from: second)
        XCTAssertEqual(puzzle.rules, .fourByFour)
        XCTAssertFalse(puzzle.solution.cells.contains(0)) // 真的按 4×4 解出来了
        let last = record(second.id.value, .easy, size: 4)
        XCTAssertEqual(HomeProgress.lastPlayedText(last, bank: merged), "上次玩的：4×4 · 简单 · 第 2 题")
        let target = HomeProgress.resumeTarget(lastPlayed: last, inProgressIDs: [second.id], bank: merged)
        XCTAssertEqual(target, .bank(second, .easy))
        XCTAssertEqual(BoardPreset.forSize(second.size), .four)
    }

    // MARK: - 档位切换

    func testPresetDifficultiesAndClamping() {
        XCTAssertEqual(BoardPreset.four.difficulties, [.easy, .hard])
        XCTAssertEqual(BoardPreset.five.difficulties, [.easy, .hard])
        XCTAssertEqual(BoardPreset.nine.difficulties, Difficulty.allCases)
        for small in [BoardPreset.four, .five] {
            XCTAssertEqual(small.clamping(.expert), .hard)
            XCTAssertEqual(small.clamping(.medium), .hard)
            XCTAssertEqual(small.clamping(.hard), .hard)
            XCTAssertEqual(small.clamping(.easy), .easy)
        }
        // 切回 9×9：四档都还能选，当前的档不变
        XCTAssertEqual(Difficulty.allCases.map { BoardPreset.nine.clamping($0) }, Difficulty.allCases)
        XCTAssertEqual(BoardPreset.allCases.map(\.accessibilityTitle), ["4×4 小棋盘", "5×5 小棋盘", "9×9 九宫格"])
        XCTAssertEqual([4, 5, 9, 7].map { BoardPreset.forSize($0) }, [.four, .five, .nine, .nine])
    }

    // MARK: - 上次玩的

    func testLastPlayedSlotsAreKeptBySizeAndDifficulty() throws {
        var records = PuzzleProgressRecords()
        records.recordLastPlayed(record("n", .easy, size: 9))
        records.recordLastPlayed(record("b", .hard, size: 4))
        records.recordLastPlayed(record("f1", .easy, size: 4))
        records.recordLastPlayed(record("c", .easy, size: 5))
        records.recordLastPlayed(record("old", .medium, size: nil)) // 很早的记录没有尺寸，当 9×9
        // 导入题不带难度：不管几乘几，都不占内置题的槽
        records.recordLastPlayed(record("i4", nil, size: 4))
        records.recordLastPlayed(record("i9", nil, size: 9))

        XCTAssertEqual(records.lastPlayed(size: 9, difficulty: .easy)?.id, fingerprint("n"))
        XCTAssertEqual(records.lastPlayedByDifficulty.medium?.id, fingerprint("old"))
        XCTAssertEqual(records.lastPlayed(size: 4, difficulty: .easy)?.id, fingerprint("f1"))
        XCTAssertEqual(records.lastPlayed(size: 4, difficulty: .hard)?.id, fingerprint("b"))
        XCTAssertEqual(records.lastPlayedBySmallBoard.fiveEasy?.id, fingerprint("c"))
        XCTAssertNil(records.lastPlayedBySmallBoard.fiveHard)
        XCTAssertNil(records.lastPlayedFixture) // 4×4 的题库题不再当成固定题
        XCTAssertEqual(records.lastPlayed?.id, fingerprint("i9"))
        XCTAssertEqual(records.schemaVersion, 1)
        XCTAssertFalse(record("f1", .easy, size: 4).isFixture)
        XCTAssertTrue(record("fixture-4", nil, size: nil).isFixture)

        // ▶ 只标在自己尺寸和难度的格子上
        let tiles = HomeProgress(entries: mixedEntries, records: records).tiles
        XCTAssertEqual(tiles.filter(\.isLastPlayed).map(\.entry.id.value), ["f1"])
        // 存盘再读回来还是一样
        let reloaded = try JSONDecoder().decode(PuzzleProgressRecords.self, from: JSONEncoder().encode(records))
        XCTAssertEqual(reloaded, records)
    }

    func testOldFilesStillLoadIntoNineByNineSlots() throws {
        let easy = #"{"id":"e","difficulty":0,"playedAt":1}"#
        let files = [
            // 上一版的文件：已经有 9×9 的四档，没有小棋盘字段
            #"{"schemaVersion":1,"completed":[],"lastPlayed":\#(easy),"lastPlayedByDifficulty":{"easy":\#(easy)}}"#,
            // 更早的文件：只有 lastPlayed
            #"{"schemaVersion":1,"completed":[],"lastPlayed":\#(easy)}"#,
        ]
        for text in files {
            let records = try JSONDecoder().decode(PuzzleProgressRecords.self, from: Data(text.utf8))
            XCTAssertEqual(records.lastPlayedByDifficulty.easy?.id, fingerprint("e"))
            XCTAssertEqual(records.lastPlayedByDifficulty.all.count, 1)
            XCTAssertTrue(records.lastPlayedBySmallBoard.all.isEmpty)
            XCTAssertEqual(records.schemaVersion, 1)
        }
        // 旧固定题只进固定题那一条，不进小棋盘题库的槽
        let fixture = #"{"schemaVersion":1,"completed":[],"lastPlayed":{"id":"fixture-4","size":4,"playedAt":1}}"#
        let records = try JSONDecoder().decode(PuzzleProgressRecords.self, from: Data(fixture.utf8))
        XCTAssertEqual(records.lastPlayedFixture?.id, HomeProgress.fixture4)
        XCTAssertTrue(records.lastPlayedBySmallBoard.all.isEmpty && records.lastPlayedByDifficulty.all.isEmpty)
    }
}
