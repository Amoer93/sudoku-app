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

    // MARK: - 鱼型技巧

    func testXWingEliminatesFromColumns() throws {
        var board = try XCTUnwrap(emptyBoard())
        for row in [0, 1] {
            let kept = [row * 9 + 5, row * 9 + 7]
            remove(digit: 5, from: rowCells(row).filter { !kept.contains($0) }, board: &board)
        }
        XCTAssertTrue(board.applyXWing())
        XCTAssertFalse(hasCandidate(board, digit: 5, at: 25))
    }

    func testXWingDoesNothingWithoutAlignedPair() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 5, from: rowCells(0).filter { $0 != 5 && $0 != 7 && $0 != 8 }, board: &board)
        remove(digit: 5, from: rowCells(1).filter { $0 != 14 && $0 != 16 }, board: &board)
        XCTAssertFalse(board.applyXWing())
    }

    func testSwordfishEliminatesFromColumns() throws {
        var board = try XCTUnwrap(emptyBoard())
        for row in [0, 4, 8] {
            let kept = [row * 9 + 2, row * 9 + 3, row * 9 + 7]
            remove(digit: 5, from: rowCells(row).filter { !kept.contains($0) }, board: &board)
        }
        XCTAssertTrue(board.applySwordfish())
        XCTAssertFalse(hasCandidate(board, digit: 5, at: 16))
    }

    func testSwordfishDoesNothingWhenSpanningFourColumns() throws {
        var board = try XCTUnwrap(emptyBoard())
        // 三行的候选列合起来有 4 列（2、3、7、8），构不成剑鱼
        let keptColumns = [0: [2, 7], 4: [3, 8], 8: [2, 8]]
        for (row, columns) in keptColumns {
            let kept = columns.map { row * 9 + $0 }
            remove(digit: 5, from: rowCells(row).filter { !kept.contains($0) }, board: &board)
        }
        XCTAssertFalse(board.applySwordfish())
    }

    // MARK: - 链式技巧

    func testXYWingEliminatesZ() throws {
        var board = try XCTUnwrap(emptyBoard())
        // pivot cell 0，两个钳子分别在同一行、同一列且不同宫，夹角 victim 为 cell 40。
        board.candidates[0] = mask([1, 2])
        board.candidates[4] = mask([1, 3])
        board.candidates[36] = mask([2, 3])
        board.candidates[40] = mask([3, 4])
        XCTAssertTrue(board.applyXYWing())
        XCTAssertFalse(hasCandidate(board, digit: 3, at: 40))
    }

    func testXYWingDoesNothingWhenPincersDoNotShareZ() throws {
        var board = try XCTUnwrap(emptyBoard())
        board.candidates[0] = mask([1, 2])
        board.candidates[1] = mask([1, 3])
        board.candidates[9] = mask([2, 4])
        XCTAssertFalse(board.applyXYWing())
    }

    func testSimpleColoringEliminatesSameColor() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 4, from: rowCells(0).filter { $0 != 0 && $0 != 1 }, board: &board)
        remove(digit: 4, from: colCells(0).filter { $0 != 0 && $0 != 9 }, board: &board)
        XCTAssertTrue(board.applySimpleColoring())
        XCTAssertTrue(hasCandidate(board, digit: 4, at: 0))
        XCTAssertFalse(hasCandidate(board, digit: 4, at: 1))
        XCTAssertFalse(hasCandidate(board, digit: 4, at: 9))
    }

    func testSimpleColoringDoesNothingWithoutConjugatePair() throws {
        var board = try XCTUnwrap(emptyBoard())
        remove(digit: 5, from: rowCells(0).filter { $0 != 0 && $0 != 1 && $0 != 7 }, board: &board)
        XCTAssertFalse(board.applySimpleColoring())
    }

    func testSimpleColoringEliminatesCellSeeingBothColors() throws {
        var board = try XCTUnwrap(emptyBoard())
        // 共轭链 2 - 0 - 27 - 28（数字 4）：0、28 同色（唯一解中的 4），2、27 同色
        remove(digit: 4, from: rowCells(0).filter { $0 != 0 && $0 != 2 }, board: &board)
        remove(digit: 4, from: colCells(0).filter { $0 != 0 && $0 != 27 }, board: &board)
        remove(digit: 4, from: rowCells(3).filter { $0 != 27 && $0 != 28 }, board: &board)
        // 10 与 0、2 同宫，两种颜色都看到，应删去候选 4（同色格互不相见，不走同色分支）
        XCTAssertTrue(board.applySimpleColoring())
        XCTAssertFalse(hasCandidate(board, digit: 4, at: 10))
        for cell in [0, 2, 27, 28] {
            XCTAssertTrue(hasCandidate(board, digit: 4, at: cell))
        }
    }
}
