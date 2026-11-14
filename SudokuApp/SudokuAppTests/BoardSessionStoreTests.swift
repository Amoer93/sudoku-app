import Foundation
@testable import SudokuApp
import SudokuEngine
import XCTest

@MainActor
final class BoardSessionStoreTests: XCTestCase {
    private var folder: URL!
    private var recordsURL: URL { folder.appendingPathComponent("records.json") }
    private var sessionURL: URL { makeStore().fileURL(for: puzzleID) }
    private let puzzle = FixtureLibrary.puzzle(for: .four)
    private let puzzleID = PuzzleFingerprint(value: "fixture-4")
    // 4×4 固定题的空格（下标）和正确数字
    private let missing: [(index: Int, value: Int)] = [(3, 4), (5, 4), (8, 2), (15, 1)]

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("session-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    func testSaveThenLoadRoundTripsAndRemoveDeletesIt() throws {
        let store = makeStore()
        let state = try makeState(filling: 2)
        store.save(state)
        XCTAssertEqual(store.load(puzzleID: puzzleID, puzzle: puzzle), state)
        store.remove(puzzleID: puzzleID)
        XCTAssertFalse(store.hasFile(for: puzzleID))
        // 文件里的指纹和文件名对不上时拒绝
        var other = state
        other.puzzleID = PuzzleFingerprint(value: "other")
        try write(try XCTUnwrap(other.encoded()), to: sessionURL)
        XCTAssertNil(store.load(puzzleID: puzzleID, puzzle: puzzle))
        XCTAssertNil(store.load(puzzleID: other.puzzleID, puzzle: puzzle))
    }

    func testBadFilesAreMovedAsideAndNewerSchemaIsLeftAlone() throws {
        let store = makeStore()
        // 太大的存档：不写，已有的也挪开
        let small = makeStore(maxFileSize: 50)
        small.save(try makeState(filling: 1))
        XCTAssertFalse(small.hasFile(for: puzzleID))
        store.save(try makeState(filling: 1))
        XCTAssertNil(small.load(puzzleID: puzzleID, puzzle: puzzle))
        XCTAssertFalse(small.hasFile(for: puzzleID))
        XCTAssertEqual(asideFileCount(), 1)
        // 坏文件：挪开，records.json 不动
        let records = Data("{\"schemaVersion\":1}".utf8)
        try write(records, to: recordsURL)
        try write(Data("not json".utf8), to: sessionURL)
        XCTAssertNil(store.load(puzzleID: puzzleID, puzzle: puzzle))
        XCTAssertFalse(store.hasFile(for: puzzleID))
        XCTAssertEqual(asideFileCount(), 2)
        XCTAssertEqual(try Data(contentsOf: recordsURL), records)
        // 新版本的文件：不覆盖、不改名、不删除
        let newer = Data("{\"schemaVersion\":99}".utf8)
        try write(newer, to: sessionURL)
        store.save(try makeState(filling: 1))
        XCTAssertNil(store.load(puzzleID: puzzleID, puzzle: puzzle))
        store.remove(puzzleID: puzzleID)
        XCTAssertEqual(try Data(contentsOf: sessionURL), newer)
        XCTAssertEqual(asideFileCount(), 2)
    }

    func testBackfillOnRestore() throws {
        // 每行：存档里已记过、记录里已有、用过全解 -> 期望总次数、存档是否还在
        let cases: [(saved: Bool, inRecords: Bool, solved: Bool, total: Int, kept: Bool)] = [
            (false, false, false, 1, false), (false, false, true, 0, true), (true, true, false, 1, false)
        ]
        for item in cases {
            try? FileManager.default.removeItem(at: folder)
            let progress = makeProgress()
            if item.inRecords { progress.markCompleted(id: puzzleID) }
            var state = try makeState(filling: missing.count)
            state.hasRecordedCompletion = item.saved
            state.usedAutoSolve = item.solved
            progress.sessions.save(state)
            _ = start(progress)
            _ = start(progress) // 第二次进入不能再加次数
            XCTAssertEqual(progress.totalCompletions, item.total)
            XCTAssertEqual(progress.sessions.hasFile(for: puzzleID), item.kept)
        }
    }

    func testStartRestoresNoticeOnlyWhenUnreadableAndAutosaveFlushesAndClears() throws {
        var progress = makeProgress()
        XCTAssertNil(start(progress).lostNotice)
        progress.sessions.save(try makeState(filling: 2))
        XCTAssertEqual(start(progress).model.grid.cells[5], 4)
        try write(Data("not json".utf8), to: sessionURL)
        let lost = start(progress)
        XCTAssertEqual(lost.lostNotice?.text, ProgressCopy.sessionLost)
        XCTAssertEqual(lost.model.grid, puzzle.givens)
        // 新版本的存档：不提示、新开一局，文件原样留着（没改名、没覆盖）
        let newer = Data("{\"schemaVersion\":99}".utf8)
        try write(newer, to: sessionURL)
        let fresh = start(progress)
        XCTAssertNil(fresh.lostNotice)
        XCTAssertEqual(fresh.model.grid, puzzle.givens)
        XCTAssertEqual(try Data(contentsOf: sessionURL), newer)
        XCTAssertEqual(progress.sessions.loadResult(puzzleID: puzzleID, puzzle: puzzle), .newerVersion)
        // 清掉上面留下的坏文件，免得影响下面的存档检查
        try? FileManager.default.removeItem(at: folder)
        progress = makeProgress()
        let launch = start(progress)
        let autosave = try XCTUnwrap(launch.autosave)
        launch.model.select(index: 3)
        launch.model.enter(4)
        autosave.noteChange()
        XCTAssertFalse(progress.sessions.hasFile(for: puzzleID))
        autosave.flush()
        XCTAssertTrue(progress.sessions.hasFile(for: puzzleID))
        autosave.clear() // 清掉之后，同一个盘面的保存不能把存档写回来
        autosave.noteChange()
        autosave.flush()
        XCTAssertFalse(progress.sessions.hasFile(for: puzzleID))
    }

    func testSummaryOnlyCountsUnfinishedNonAutoSolveSessions() throws {
        let store = makeStore()
        let other = PuzzleFingerprint(value: "fixture-5")
        let third = PuzzleFingerprint(value: "solved")
        XCTAssertEqual(store.summary(for: puzzleID), .none) // 没有文件
        XCTAssertTrue(store.inProgressIDs().isEmpty)
        var state = try makeState(filling: 1)
        store.save(state)
        state.puzzleID = other
        store.save(state)
        state.puzzleID = third
        state.usedAutoSolve = true
        store.save(state)
        let summaries = [puzzleID, other, third].map { store.summary(for: $0) }
        XCTAssertEqual(summaries, [.inProgress, .inProgress, .autoSolved])
        XCTAssertEqual(store.inProgressIDs(), [puzzleID, other])
        try write(Data("not json".utf8), to: store.fileURL(for: other))
        try write(Data("{\"schemaVersion\":99}".utf8), to: store.fileURL(for: third))
        XCTAssertEqual(store.summary(for: other), .none) // 读不出来
        XCTAssertEqual(store.summary(for: third), .newerVersion)
        XCTAssertEqual(store.inProgressIDs(), [puzzleID])
        // 文件名和里面的指纹对不上：不算
        try FileManager.default.removeItem(at: store.fileURL(for: other))
        try FileManager.default.moveItem(at: store.fileURL(for: puzzleID), to: store.fileURL(for: other))
        XCTAssertEqual(store.summary(for: other), .none)
        XCTAssertTrue(store.inProgressIDs().isEmpty)
    }

    private func makeStore(maxFileSize: Int = BoardSessionStore.defaultMaxFileSize) -> BoardSessionStore {
        BoardSessionStore(folderURL: folder.appendingPathComponent("sessions"), maxFileSize: maxFileSize)
    }

    private func makeProgress() -> PuzzleProgressModel {
        PuzzleProgressModel(store: PuzzleProgressStore(fileURL: recordsURL), sessions: makeStore())
    }

    private func start(_ progress: PuzzleProgressModel) -> BoardSessionLauncher.Launch {
        let id = ProgressPuzzleIdentity(bankEntry: nil, preset: .four, isCustomPuzzle: false)
        return BoardSessionLauncher.start(
            title: "4×4", puzzle: puzzle, identity: id, progress: progress, engine: FixtureBoardEngine()
        )
    }

    private func makeState(filling count: Int) throws -> BoardSessionState {
        let model = BoardViewModel(title: "4×4", puzzle: puzzle, engine: FixtureBoardEngine())
        for item in missing.prefix(count) {
            model.select(index: item.index)
            model.enter(item.value)
        }
        return try XCTUnwrap(model.makeSessionState(puzzleID: puzzleID, savedAt: Date(timeIntervalSince1970: 1)))
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func asideFileCount() -> Int {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: sessionURL.deletingLastPathComponent().path))
        return (names ?? []).filter { $0.contains(".corrupt-") }.count
    }
}
