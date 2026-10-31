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

    // MARK: - 子集技巧

    func testNakedPairEliminatesUnion() throws {
        var board = try XCTUnwrap(emptyBoard())
        // 第 0 行数字 4、8 的解分别在 cell 0、1，可安全地从其他格消除。
        board.candidates[0] = mask([4, 8])
        board.candidates[1] = mask([4, 8])
        XCTAssertTrue(board.applyNakedSubset(size: 2))
        XCTAssertEqual(board.candidates[2], mask([1, 2, 3, 5, 6, 7, 9]))
    }

    func testNakedPairDoesNothingWithoutTwoCells() throws {
        var board = try XCTUnwrap(emptyBoard())
        board.candidates[0] = mask([4, 8])
        XCTAssertFalse(board.applyNakedSubset(size: 2))
    }

    func testHiddenPairRemovesOtherCandidates() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 4, from: rowCells(0).filter { $0 != 0 && $0 != 1 }, board: &board)
        remove(digit: 8, from: rowCells(0).filter { $0 != 0 && $0 != 1 }, board: &board)
        XCTAssertTrue(board.applyHiddenSubset(size: 2))
        XCTAssertEqual(board.candidates[0], mask([4, 8]))
        XCTAssertEqual(board.candidates[1], mask([4, 8]))
    }

    func testHiddenPairDoesNothingWhenDigitsSpread() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 4, from: rowCells(0).filter { $0 != 0 && $0 != 1 && $0 != 2 }, board: &board)
        XCTAssertFalse(board.applyHiddenSubset(size: 2))
    }

    func testNakedTripleEliminatesUnion() throws {
        var board = try XCTUnwrap(emptyBoard())
        // 第 0 行数字 4、8、3 的解分别在 cell 0、1、2。
        for col in 0 ..< 3 { board.candidates[col] = mask([4, 8, 3]) }
        XCTAssertTrue(board.applyNakedSubset(size: 3))
        XCTAssertEqual(board.candidates[3], mask([1, 2, 5, 6, 7, 9]))
    }

    func testHiddenTripleRemovesOtherCandidates() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digits: [4, 8, 3], from: rowCells(0).filter { $0 != 0 && $0 != 1 && $0 != 2 }, board: &board)
        XCTAssertTrue(board.applyHiddenSubset(size: 3))
        XCTAssertEqual(board.candidates[0], mask([3, 4, 8]))
    }

    func testNakedQuadEliminatesUnion() throws {
        var board = try XCTUnwrap(emptyBoard())
        for col in 0 ..< 4 { board.candidates[col] = mask([3, 4, 8, 9]) }
        XCTAssertTrue(board.applyNakedSubset(size: 4))
        XCTAssertEqual(board.candidates[4], mask([1, 2, 5, 6, 7]))
    }

    func testHiddenQuadRemovesOtherCandidates() throws {
        var board = try XCTUnwrap(emptyBoard())
        let cells = rowCells(0).filter { $0 != 0 && $0 != 1 && $0 != 2 && $0 != 3 }
        remove(digits: [4, 8, 3, 9], from: cells, board: &board)
        XCTAssertTrue(board.applyHiddenSubset(size: 4))
        XCTAssertEqual(board.candidates[0], mask([3, 4, 8, 9]))
    }

    // MARK: - 宫行列技巧

    func testPointingEliminatesFromRow() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 4, from: boxCells(0).filter { $0 != 0 && $0 != 1 }, board: &board)
        XCTAssertTrue(board.applyPointing())
        XCTAssertFalse(hasCandidate(board, digit: 4, at: 3))
    }

    func testPointingDoesNothingWhenDigitSpansTwoRowsAndColumns() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 4, from: boxCells(0).filter { $0 != 0 && $0 != 10 }, board: &board)
        XCTAssertFalse(board.applyPointing())
    }

    func testBoxLineReductionEliminatesFromBox() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 4, from: rowCells(0).filter { $0 != 0 && $0 != 1 && $0 != 2 }, board: &board)
        XCTAssertTrue(board.applyBoxLineReduction())
        XCTAssertFalse(hasCandidate(board, digit: 4, at: 9))
    }

    func testBoxLineReductionDoesNothingWhenDigitSpansTwoBoxes() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 4, from: rowCells(0).filter { $0 != 0 && $0 != 5 }, board: &board)
        XCTAssertFalse(board.applyBoxLineReduction())
    }
}
