import BoardVision
@testable import SudokuApp
import XCTest

/// 测拍照导入的状态：建盘、待确认集合、编辑、冲突和解的情况。
@MainActor
final class PhotoImportViewModelTests: XCTestCase {
    private func result(size: Int, digits: [Int: Int], uncertain: Set<Int> = []) -> RecognitionResult {
        var cells: [CellRecognition] = []
        for index in 0 ..< size * size {
            let digit = digits[index]
            var status = CellStatus.empty
            if digit != nil {
                status = uncertain.contains(index) ? .lowConfidence : .certain
            }
            cells.append(CellRecognition(digit: digit, confidence: 0.9, status: status))
        }
        return RecognitionResult(size: size, cells: cells)
    }

    func testDefaultPresetIsNineByNine() {
        XCTAssertEqual(PhotoImportViewModel.guessPreset(), .nine)
        XCTAssertEqual(PhotoImportViewModel().preset, .nine)
    }

    func testApplyBuildsGridAndReviewSet() {
        let model = PhotoImportViewModel()
        model.apply(result: result(size: 4, digits: [0: 1, 5: 3], uncertain: [5]))
        XCTAssertEqual(model.preset, .four)
        XCTAssertEqual(model.grid.cells[0], 1)
        XCTAssertEqual(model.grid.cells[5], 3)
        XCTAssertEqual(model.reviewIndexes, [5])
    }

    func testSetDigitUpdatesGridAndClearsReviewMark() {
        let model = PhotoImportViewModel()
        model.apply(result: result(size: 4, digits: [5: 3], uncertain: [5]))
        model.selectedIndex = 5
        model.setDigit(2)
        XCTAssertEqual(model.grid.cells[5], 2)
        XCTAssertTrue(model.reviewIndexes.isEmpty)
        model.clear()
        XCTAssertEqual(model.grid.cells[5], Grid.emptyCell)
    }

    func testDuplicateDigitsAreConflictsButStillImportable() {
        let model = PhotoImportViewModel()
        model.apply(result: result(size: 4, digits: [0: 1, 1: 1]))
        XCTAssertEqual(model.conflicts, [0, 1])
        XCTAssertEqual(model.messages, [PhotoImportCopy.conflicts])
        let puzzle = model.makePuzzle()
        XCTAssertEqual(puzzle.rules, .fourByFour)
        XCTAssertEqual(puzzle.givens, model.grid)
    }

    func testUniqueSolutionStatus() {
        let model = PhotoImportViewModel()
        let digits = [0: 1, 1: 2, 2: 3, 4: 3, 6: 1, 7: 2, 9: 1, 10: 4, 11: 3, 12: 4, 13: 3, 14: 2]
        model.apply(result: result(size: 4, digits: digits))
        XCTAssertEqual(model.solutionStatus, .unique)
        XCTAssertTrue(model.messages.isEmpty)
    }

    func testNoSolutionStatusWithoutConflicts() {
        let model = PhotoImportViewModel()
        // 第一行的两个空格都只能填 4，但没有任何格子直接冲突
        model.apply(result: result(size: 4, digits: [0: 1, 1: 2, 6: 3, 11: 3]))
        XCTAssertTrue(model.conflicts.isEmpty)
        XCTAssertEqual(model.solutionStatus, .none)
        XCTAssertEqual(model.messages, [PhotoImportCopy.noSolution])
    }

    func testEmptyBoardHasMultipleSolutions() {
        let model = PhotoImportViewModel()
        model.apply(result: result(size: 4, digits: [:]))
        XCTAssertEqual(model.solutionStatus, .multiple)
        XCTAssertEqual(model.messages, [PhotoImportCopy.multipleSolutions])
    }
}
