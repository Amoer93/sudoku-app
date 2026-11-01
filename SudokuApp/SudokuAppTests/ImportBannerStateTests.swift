import BoardVision
@testable import SudokuApp
import enum SudokuEngine.Difficulty
import struct SudokuEngine.PuzzleBank
import struct SudokuEngine.PuzzleBankEntry
import struct SudokuEngine.PuzzleFingerprint
import XCTest

/// 测导入提示横幅：显示、自动消失、点击消失、旧倒计时不误关，以及确认导入后提示的时机。
@MainActor
final class ImportBannerStateTests: XCTestCase {
    private let added = ImportNotice(text: ImportBankCopy.added(.easy), existingEntry: nil)
    /// 倒计时永远不到点，用来看横幅是否还在。
    private let state = ImportBannerState(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })

    func testAutoDismissAfterDelay() async {
        let instant = ImportBannerState(sleep: { _ in })
        await instant.show(added).value
        XCTAssertNil(instant.notice)
    }

    func testShowsNoticeThenTapDismisses() {
        state.show(added)
        XCTAssertEqual(state.notice, added)
        state.dismiss()
        XCTAssertNil(state.notice)
    }

    func testStaleTimerDoesNotDismissNewerBanner() async {
        var sleepCount = 0
        // 第一次倒计时立刻到点，之后的都不到点
        let twoStep = ImportBannerState(sleep: { _ in
            sleepCount += 1
            if sleepCount > 1 {
                try await Task.sleep(for: .seconds(3600))
            }
        })
        let oldTimer = twoStep.show(added)
        twoStep.show(ImportNotice(text: ImportBankCopy.ungradable, existingEntry: nil))
        await oldTimer.value
        XCTAssertEqual(twoStep.notice?.text, ImportBankCopy.ungradable)
    }

    func testDuplicateExposesExistingEntryAction() async throws {
        let existing = PuzzleBankEntry(
            id: PuzzleFingerprint(value: "x"),
            size: 9,
            givens: FixtureLibrary.puzzle(for: .nine).givens.cells,
            difficulty: .easy,
            seRating: 1.0,
            score: 0,
            source: .builtin,
            addedAt: Date(timeIntervalSince1970: 0)
        )
        state.show(ImportNotice(text: ImportBankCopy.duplicate, existingEntry: existing))
        XCTAssertEqual(state.notice?.existingEntry, existing)
        let puzzle = await state.existingPuzzle()
        XCTAssertEqual(puzzle?.givens.cells, existing.givens)
    }

    func testConfirmImportReturnsPuzzleFirstThenSetsNotice() async throws {
        // 只在内存里入库，不碰磁盘
        let importer = LibraryImporter(bank: try PuzzleBank.load(userData: nil)) { _ in }
        let model = PhotoImportViewModel(importer: importer)
        let empty = CellRecognition(digit: nil, confidence: 0.9, status: .empty)
        var cells = [CellRecognition](repeating: empty, count: 81)
        cells[0] = CellRecognition(digit: 1, confidence: 0.9, status: .certain)
        model.apply(result: RecognitionResult(size: 9, cells: cells))
        _ = model.confirmImport()
        XCTAssertNil(model.importNotice)
        await model.importTask?.value
        XCTAssertNotNil(model.importNotice)
    }

    func testConfirmImportOfFourByFourStaysPlayableAndSkipsBank() async throws {
        // persist 在 actor 里跑，计数要线程安全
        let counter = PersistCounter()
        let importer = LibraryImporter(bank: try PuzzleBank.load(userData: nil)) { _ in counter.increment() }
        let model = PhotoImportViewModel(importer: importer)
        let empty = CellRecognition(digit: nil, confidence: 0.9, status: .empty)
        var cells = [CellRecognition](repeating: empty, count: 16)
        cells[0] = CellRecognition(digit: 1, confidence: 0.9, status: .certain)
        XCTAssertTrue(model.apply(result: RecognitionResult(size: 4, cells: cells)))

        let puzzle = model.confirmImport()
        // 4x4 不入库，但题目要能正常开局
        XCTAssertEqual(puzzle.rules.size, 4)
        XCTAssertEqual(puzzle.givens.cells, model.grid.cells)
        let board = BoardViewModel(title: "4x4", puzzle: puzzle)
        XCTAssertEqual(board.rules.size, 4)

        await model.importTask?.value
        XCTAssertEqual(model.importNotice?.text, LibraryCopy.message(.unsupportedSize))
        XCTAssertNil(model.importNotice?.existingEntry)
        XCTAssertEqual(counter.count, 0)
    }

    /// 数存盘次数的小工具，加锁后可以跨线程用。
    private final class PersistCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func increment() {
            lock.lock()
            value += 1
            lock.unlock()
        }
    }
}
