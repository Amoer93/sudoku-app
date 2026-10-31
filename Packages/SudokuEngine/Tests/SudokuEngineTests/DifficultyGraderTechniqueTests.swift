import SudokuEngine
@testable import SudokuEngine
import XCTest

final class DifficultyGraderTechniqueTests: XCTestCase {
    // MARK: - 单格技巧

    func testNakedSinglePlacesDigit() throws {
        var board = try XCTUnwrap(emptyBoard())
        board.candidates[0] = mask([4])
        XCTAssertTrue(board.applyNakedSingle())
        XCTAssertTrue(board.fixed[0])
        XCTAssertEqual(board.candidates[0], mask([4]))
    }

    func testNakedSingleDoesNothingWhenNoSingle() throws {
        var board = try XCTUnwrap(emptyBoard())
        board.candidates[0] = mask([1, 2])
        XCTAssertFalse(board.applyNakedSingle())
    }

    func testHiddenSingleInRow() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 1, from: rowCells(0).filter { $0 != 5 }, board: &board)
        board.candidates[5] = mask([1, 2])
        XCTAssertTrue(board.applyHiddenSingle(boxesOnly: false))
        XCTAssertTrue(board.fixed[5])
        XCTAssertEqual(board.candidates[5], mask([1]))
    }

    func testHiddenSingleDoesNothingWhenAmbiguous() throws {
        var board = try XCTUnwrap(emptyBoard())
        // 第 0 行数字 4 的解在 cell 0，保留 cell 0、1 两个候选，制造“二义性”。
        remove(digit: 4, from: rowCells(0).filter { $0 != 0 && $0 != 1 }, board: &board)
        XCTAssertFalse(board.applyHiddenSingle(boxesOnly: false))
        XCTAssertFalse(board.applyHiddenSingle(boxesOnly: true))
    }
}
