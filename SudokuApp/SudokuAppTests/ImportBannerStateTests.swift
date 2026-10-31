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

    func testDuplicateExposesExistingEntryAction() throws {
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
        XCTAssertEqual(state.existingPuzzle()?.givens.cells, existing.givens)
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
}
