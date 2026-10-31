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
            if digit != nil { status = uncertain.contains(index) ? .lowConfidence : .certain }
            cells.append(CellRecognition(digit: digit, confidence: 0.9, status: status))
        }
        return RecognitionResult(size: size, cells: cells)
    }

    private func appliedFourModel(digits: [Int: Int], uncertain: Set<Int> = []) -> PhotoImportViewModel {
        let model = PhotoImportViewModel()
        model.apply(result: result(size: 4, digits: digits, uncertain: uncertain))
        return model
    }

    func testDefaultPresetIsNineByNine() {
        XCTAssertEqual([PhotoImportViewModel.guessPreset(), PhotoImportViewModel().preset], [.nine, .nine])
    }

    func testApplyBuildsGridAndReviewSet() {
        let model = appliedFourModel(digits: [0: 1, 5: 3], uncertain: [5])
        XCTAssertEqual(model.preset, .four)
        XCTAssertEqual([model.grid.cells[0], model.grid.cells[5]], [1, 3])
        XCTAssertEqual(model.reviewIndexes, [5])
    }

    func testSetDigitUpdatesGridAndClearsReviewMark() {
        let model = appliedFourModel(digits: [5: 3], uncertain: [5])
        model.selectedIndex = 5
        model.setDigit(2)
        XCTAssertEqual(model.grid.cells[5], 2)
        XCTAssertTrue(model.reviewIndexes.isEmpty)
        model.clear()
        XCTAssertEqual(model.grid.cells[5], Grid.emptyCell)
    }

    func testDuplicateDigitsAreConflictsButStillImportable() {
        let model = appliedFourModel(digits: [0: 1, 1: 1])
        XCTAssertEqual(model.conflicts, [0, 1])
        XCTAssertEqual(model.messages, [PhotoImportCopy.conflicts])
        let puzzle = model.makePuzzle()
        XCTAssertEqual(puzzle.rules, .fourByFour)
        XCTAssertEqual(puzzle.givens, model.grid)
    }

    func testUniqueSolutionStatus() {
        let model = appliedFourModel(
            digits: [0: 1, 1: 2, 2: 3, 4: 3, 6: 1, 7: 2, 9: 1, 10: 4, 11: 3, 12: 4, 13: 3, 14: 2])
        XCTAssertEqual(model.solutionStatus, .unique)
        XCTAssertTrue(model.messages.isEmpty)
    }

    func testNoSolutionStatusWithoutConflicts() {
        // 第一行的两个空格都只能填 4，但没有任何格子直接冲突
        let model = appliedFourModel(digits: [0: 1, 1: 2, 6: 3, 11: 3])
        XCTAssertTrue(model.conflicts.isEmpty)
        XCTAssertEqual(model.solutionStatus, .noSolution)
        XCTAssertEqual(model.messages, [PhotoImportCopy.noSolution])
    }

    func testEmptyBoardHasMultipleSolutions() {
        let model = appliedFourModel(digits: [:])
        XCTAssertEqual(model.solutionStatus, .multiple)
        XCTAssertEqual(model.messages, [PhotoImportCopy.multipleSolutions])
    }

    func testLoadBoardNotFoundKeepsState() async throws {
        let four = result(size: 4, digits: [0: 1])
        let shouldFail = FailSwitch()
        let model = fakeModel(detect: {
            if shouldFail.isOn { throw BoardVisionError.boardNotFound }
            return $0
        }, recognize: { _, _ in four })
        try await loadThenFail(model, shouldFail)
        XCTAssertEqual(model.errorMessage, PhotoImportCopy.boardNotFound)
        assertKeeps(model, .four, four)
    }

    func testChangeSizeFailureKeepsOldState() async throws {
        let nine = result(size: 9, digits: [0: 1])
        let model = fakeModel(recognize: { _, size in
            guard size == 9 else { throw BoardVisionError.imageProcessingFailed }
            return nine
        })
        await model.load(image: try image(4))
        await model.changeSize(.four)
        assertKeeps(model, .nine, nine)
        XCTAssertEqual(model.errorMessage, PhotoImportCopy.recognitionFailed)
    }

    func testApplyWithBrokenGridKeepsPreset() {
        let model = appliedFourModel(digits: [0: 1])
        XCTAssertFalse(model.apply(result: RecognitionResult(size: 9, cells: []))) // 格子数对不上
        assertKeeps(model, .four, result(size: 4, digits: [0: 1]))
    }

    func testStaleLoadResultIsDiscarded() async throws {
        let fast = result(size: 4, digits: [0: 1])
        // 宽 8 的图是慢请求
        let model = try await withBlockedLoad(slow: result(size: 4, digits: [0: 2]), fast: fast) { model in
            await model.load(image: try self.image(4))
        }
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.result, fast)
        XCTAssertEqual(model.grid.cells[0], 1)
    }

    func testChangeSizeDuringLoadDiscardsLoadResult() async throws {
        let model = try await withBlockedLoad(slow: result(size: 9, digits: [0: 1])) { await $0.changeSize(.four) }
        XCTAssertEqual(model.preset, .four)
        XCTAssertNil(model.result)
        XCTAssertEqual(model.grid.size, 4)
    }

    func testLoadRecognizeErrorKeepsPreset() async throws {
        let four = result(size: 4, digits: [0: 1])
        let shouldFail = FailSwitch()
        let model = fakeModel(recognize: { _, _ in
            if shouldFail.isOn { throw BoardVisionError.imageProcessingFailed }
            return four
        })
        try await loadThenFail(model, shouldFail)
        XCTAssertEqual(model.errorMessage, PhotoImportCopy.recognitionFailed)
        assertKeeps(model, .four, four)
    }

    private final class FailSwitch: @unchecked Sendable {
        var isOn = false
    }

    private func loadThenFail(_ model: PhotoImportViewModel, _ shouldFail: FailSwitch) async throws {
        await model.load(image: try image(4))
        shouldFail.isOn = true
        await model.load(image: try image(4))
    }

    private func assertKeeps(_ model: PhotoImportViewModel, _ preset: BoardPreset, _ expected: RecognitionResult) {
        XCTAssertEqual(model.preset, preset)
        XCTAssertEqual(model.result, expected)
        XCTAssertEqual(model.grid.size, expected.size)
    }

    /// Runs `action` while an 8-wide load is stuck in recognize; other images return `fast` if given.
    private func withBlockedLoad(
        slow: RecognitionResult,
        fast: RecognitionResult? = nil,
        action: (PhotoImportViewModel) async throws -> Void
    ) async throws -> PhotoImportViewModel {
        let started = expectation(description: "slow started")
        let gate = DispatchSemaphore(value: 0)
        let model = fakeModel(recognize: { image, _ in
            if let fastResult = fast, image.width != 8 { return fastResult }
            started.fulfill()
            gate.wait()
            return slow
        })
        let slowTask = Task { await model.load(image: try image(8)) }
        await fulfillment(of: [started], timeout: 5)
        try await action(model)
        gate.signal()
        try await slowTask.value
        return model
    }

    private func fakeModel(
        detect: @escaping @Sendable (CGImage) throws -> CGImage = { $0 },
        recognize: @escaping @Sendable (CGImage, Int) throws -> RecognitionResult
            = { _, _ in throw BoardVisionError.imageProcessingFailed }
    ) -> PhotoImportViewModel {
        PhotoImportViewModel(detect: detect, recognize: recognize)
    }

    private func image(_ width: Int) throws -> CGImage {
        let context = CGContext(data: nil, width: width, height: width, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)
        return try XCTUnwrap(context?.makeImage())
    }
}
