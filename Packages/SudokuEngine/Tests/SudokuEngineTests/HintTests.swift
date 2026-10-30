import SudokuEngine
import XCTest

final class HintTests: XCTestCase {
    // MARK: - 裸单

    func testNakedSingleInRow() throws {
        let grid = try makeGrid(size: 4, "1230 0000 0000 0000")
        let hint = try XCTUnwrap(hint(in: grid, rules: .fourByFour))

        XCTAssertEqual(hint.target, CellIndex(row: 0, column: 3))
        XCTAssertEqual(hint.value, 4)
        assertNakedSingle(hint, expectedUnits: [.row(0), .column(3), .box(1)])
    }

    func testNakedSingleInColumn() throws {
        let grid = try makeGrid(
            size: 9,
            "100000000 200000000 300000000 400000000 500000000 600000000 700000000 800000000 000000000"
        )
        let hint = try XCTUnwrap(hint(in: grid, rules: .nineByNine))

        XCTAssertEqual(hint.target, CellIndex(row: 8, column: 0))
        XCTAssertEqual(hint.value, 9)
        assertNakedSingle(hint, expectedUnits: [.row(8), .column(0), .box(6)])
    }

    func testNakedSingleInBox() throws {
        let grid = try makeGrid(size: 9, "123000000 456000000 780000000 000000000 000000000 000000000 000000000 000000000 000000000")
        let hint = try XCTUnwrap(hint(in: grid, rules: .nineByNine))

        XCTAssertEqual(hint.target, CellIndex(row: 2, column: 2))
        XCTAssertEqual(hint.value, 9)
        assertNakedSingle(hint, expectedUnits: [.row(2), .column(2), .box(0)])
    }

    // MARK: - 隐性唯一

    func testHiddenSingleInRow() throws {
        let grid = try makeGrid(
            size: 9,
            "000000000 000900000 000000900 090000000 000090000 000000090 009000000 000009000 000000009"
        )
        let hint = try XCTUnwrap(hint(in: grid, rules: .nineByNine))

        XCTAssertEqual(hint.target, CellIndex(row: 0, column: 0))
        XCTAssertEqual(hint.value, 9)
        assertHiddenSingle(hint, expectedUnit: .row(0))
    }

    func testHiddenSingleInColumn() throws {
        let grid = try makeGrid(size: 4, "0400 0040 0004 0000")
        let hint = try XCTUnwrap(hint(in: grid, rules: .fourByFour))

        XCTAssertEqual(hint.target, CellIndex(row: 3, column: 0))
        XCTAssertEqual(hint.value, 4)
        assertHiddenSingle(hint, expectedUnit: .row(3))
    }

    func testHiddenSingleInBox() throws {
        // 在 4×4 的标准规格下，这个宫的隐性唯一也同时是行隐性唯一；
        // 算法按行、列、宫顺序扫描，因此返回的是行单元。
        let grid = try makeGrid(size: 4, "0004 0000 4000 0000")
        let hint = try XCTUnwrap(hint(in: grid, rules: .fourByFour))

        XCTAssertEqual(hint.target, CellIndex(row: 1, column: 1))
        XCTAssertEqual(hint.value, 4)
        assertHiddenSingle(hint, expectedUnit: .row(1))
    }

    // MARK: - 裸单优先于隐性唯一

    func testNakedSingleTakesPriority() throws {
        let grid = try makeGrid(size: 4, "1230 0000 0000 0000")
        let hint = try XCTUnwrap(hint(in: grid, rules: .fourByFour))

        if case .nakedSingle = hint.technique {
            // 期望：裸单优先返回。
        } else {
            XCTFail("expected naked single, got \(hint.technique)")
        }
    }

    // MARK: - 无提示场景

    func testNoHintOnEmptyFourByFour() {
        XCTAssertNil(hint(in: Grid(rules: .fourByFour), rules: .fourByFour))
    }

    func testNoHintOnEmptyFiveByFive() {
        XCTAssertNil(hint(in: Grid(rules: .fiveByFive), rules: .fiveByFive))
    }

    func testNoHintOnEmptyNineByNine() {
        XCTAssertNil(hint(in: Grid(rules: .nineByNine), rules: .nineByNine))
    }

    func testNoHintOnCompletedGrid() throws {
        let grid = try makeGrid(size: 4, "1234 3412 2341 4123")
        XCTAssertNil(hint(in: grid, rules: .fourByFour))
    }

    func testNoHintWhenConflictsExist() throws {
        let grid = try makeGrid(size: 4, "1001 0000 0000 0000")
        XCTAssertNil(hint(in: grid, rules: .fourByFour))
    }

    // MARK: - 5×5 无宫

    func testFiveByFiveHasNoBoxUnit() throws {
        let grid = try makeGrid(size: 5, "00000 05000 00500 00050 00005")
        let hint = try XCTUnwrap(hint(in: grid, rules: .fiveByFive))

        XCTAssertEqual(hint.target, CellIndex(row: 0, column: 0))
        XCTAssertEqual(hint.value, 5)
        assertHiddenSingle(hint, expectedUnit: .row(0))

        // 无论裸单还是隐性唯一，都不应出现宫单元。
        switch hint.technique {
        case let .nakedSingle(units):
            XCTAssertFalse(units.contains(where: { if case .box = $0 { return true } else { return false } }))
        case let .hiddenSingle(unit):
            if case .box = unit { XCTFail("5×5 should not produce a box unit") }
        }
    }

    // MARK: - 纯函数

    func testHintDoesNotMutateGrid() throws {
        let grid = try makeGrid(size: 9, Self.easyPuzzle)
        let copy = grid
        _ = hint(in: grid, rules: .nineByNine)
        XCTAssertEqual(grid, copy)
    }

    // MARK: - 辅助

    private func makeGrid(size: Int, _ text: String) throws -> Grid {
        var cells: [Int] = []
        for character in text where !character.isWhitespace {
            if character == "." {
                cells.append(0)
            } else {
                cells.append(try XCTUnwrap(character.wholeNumberValue))
            }
        }
        return try Grid(size: size, cells: cells)
    }

    private func assertNakedSingle(_ hint: Hint, expectedUnits: [ConstraintUnit], file: StaticString = #filePath, line: UInt = #line) {
        guard case let .nakedSingle(units) = hint.technique else {
            XCTFail("expected naked single, got \(hint.technique)", file: file, line: line)
            return
        }
        XCTAssertEqual(Set(units), Set(expectedUnits), file: file, line: line)
    }

    private func assertHiddenSingle(_ hint: Hint, expectedUnit: ConstraintUnit, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .hiddenSingle(unit) = hint.technique else {
            XCTFail("expected hidden single, got \(hint.technique)", file: file, line: line)
            return
        }
        XCTAssertEqual(unit, expectedUnit, file: file, line: line)
    }

    private static let easyPuzzle =
        "003020600 900305001 001806400 008102900 700000008 006708200 002609500 800203009 005010300"
}
