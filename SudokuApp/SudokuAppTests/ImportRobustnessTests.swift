import BoardVision
@testable import SudokuApp
import struct SudokuEngine.PuzzleBank
import struct SudokuEngine.PuzzleBankEntry
import struct SudokuEngine.PuzzleFingerprint
import XCTest

/// 测后台求解、重复导入时取消旧任务，以及存盘失败不崩溃。
@MainActor
final class ImportRobustnessTests: XCTestCase {
    private struct DiskFullError: Error {}

    private func makeEntry() -> PuzzleBankEntry {
        PuzzleBankEntry(
            id: PuzzleFingerprint(value: "async-entry"), size: 9,
            givens: FixtureLibrary.puzzle(for: .nine).givens.cells,
            difficulty: .easy, seRating: 1.0, score: 0, source: .builtin,
            addedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func applyOneGiven(to model: PhotoImportViewModel) {
        let empty = CellRecognition(digit: nil, confidence: 0.9, status: .empty)
        var cells = [CellRecognition](repeating: empty, count: 81)
        cells[0] = CellRecognition(digit: 1, confidence: 0.9, status: .certain)
        model.apply(result: RecognitionResult(size: 9, cells: cells))
    }

    func testAsyncResolveMatchesSyncPuzzle() async {
        let entry = makeEntry()
        let resolved = await LibraryViewModel.resolvePuzzle(for: entry)
        let expected = LibraryViewModel(bank: PuzzleBank(entries: [entry])).puzzle(for: entry)
        XCTAssertEqual(resolved, expected)
        XCTAssertEqual(resolved.givens.cells, entry.givens)
        XCTAssertFalse(resolved.solution.cells.contains(Grid.emptyCell))
    }

    func testNewGamePuzzleAsyncReturnsNilForEmptyBank() async {
        let model = LibraryViewModel(bank: PuzzleBank(entries: []))
        let puzzle = await model.newGamePuzzleAsync(difficulty: .easy)
        XCTAssertNil(puzzle)
    }

    func testConfirmImportCancelsPreviousTask() async throws {
        let importer = LibraryImporter(bank: try PuzzleBank.load(userData: nil)) { _ in }
        let model = PhotoImportViewModel(importer: importer)
        applyOneGiven(to: model)

        _ = model.confirmImport()
        let first = try XCTUnwrap(model.importTask)
        _ = model.confirmImport()
        let second = try XCTUnwrap(model.importTask)

        XCTAssertTrue(first.isCancelled)
        XCTAssertFalse(second.isCancelled)
        await second.value
        XCTAssertNotNil(model.importNotice)
    }

    func testSaveFailureDoesNotCrashAndStillReturnsNotice() async throws {
        let importer = LibraryImporter(bank: try PuzzleBank.load(userData: nil)) { _ in throw DiskFullError() }
        let notice = await importer.add(FixtureLibrary.puzzle(for: .nine).givens, rules: .nineByNine)
        XCTAssertTrue(notice.text.hasPrefix("已加入题库："))
    }
}
