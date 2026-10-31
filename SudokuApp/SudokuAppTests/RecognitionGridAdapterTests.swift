import BoardVision
@testable import SudokuApp
import XCTest

/// 测识别结果到 Grid 的转换和复核格子下标。
final class RecognitionGridAdapterTests: XCTestCase {
    private func cell(_ digit: Int?, _ status: CellStatus = .certain) -> CellRecognition {
        CellRecognition(digit: digit, confidence: 0.9, status: status)
    }

    private func result(size: Int, filled: [Int: CellRecognition]) -> RecognitionResult {
        var cells = Array(repeating: cell(nil, .empty), count: size * size)
        for (index, value) in filled {
            cells[index] = value
        }
        return RecognitionResult(size: size, cells: cells)
    }

    func testFourByFourMapsDigitsAndEmptyToZero() throws {
        let recognition = result(size: 4, filled: [0: cell(1), 5: cell(3), 15: cell(4)])
        let grid = try RecognitionGridAdapter.makeGrid(recognition)
        XCTAssertEqual(grid.size, 4)
        XCTAssertEqual(grid.cells[0], 1)
        XCTAssertEqual(grid.cells[1], Grid.emptyCell)
        XCTAssertEqual(grid.cells[5], 3)
        XCTAssertEqual(grid.cells[15], 4)
    }

    func testNineByNineMapsDigitsAndEmptyToZero() throws {
        let recognition = result(size: 9, filled: [0: cell(9), 40: cell(5), 80: cell(1)])
        let grid = try RecognitionGridAdapter.makeGrid(recognition)
        XCTAssertEqual(grid.size, 9)
        XCTAssertEqual(grid.cells.count, 81)
        XCTAssertEqual(grid.cells[0], 9)
        XCTAssertEqual(grid.cells[40], 5)
        XCTAssertEqual(grid.cells[80], 1)
        XCTAssertEqual(grid.cells[1], Grid.emptyCell)
    }

    func testReviewIndexesCollectLowConfidenceAndToConfirm() {
        let recognition = result(size: 4, filled: [
            0: cell(1),
            2: cell(2, .lowConfidence),
            7: cell(nil, .toConfirm),
            9: cell(3, .toConfirm)
        ])
        XCTAssertEqual(RecognitionGridAdapter.reviewIndexes(recognition), [2, 7, 9])
    }

    func testReviewIndexesEmptyWhenAllCertain() {
        let recognition = result(size: 9, filled: [0: cell(1), 10: cell(2)])
        XCTAssertTrue(RecognitionGridAdapter.reviewIndexes(recognition).isEmpty)
    }

    func testUnsupportedSizeThrows() {
        let recognition = result(size: 6, filled: [:])
        XCTAssertThrowsError(try RecognitionGridAdapter.makeGrid(recognition)) { error in
            XCTAssertEqual(error as? Grid.ValidationError, .unsupportedSize(6))
        }
    }
}
