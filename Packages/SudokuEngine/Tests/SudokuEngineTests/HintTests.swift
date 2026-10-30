import SudokuEngine
import XCTest

final class HintTests: XCTestCase {
    // MARK: - 裸单

    func testNakedSingleInRow() throws {
        try assertHint("1230 0000 0000 0000", rules: .fourByFour, at: (0, 3), value: 4,
                       .nakedSingle(reasonUnits: [.row(0), .column(3), .box(1)]))
    }

    func testNakedSingleInColumn() throws {
        let text = "100000000 200000000 300000000 400000000 500000000 600000000 700000000 800000000 000000000"
        try assertHint(text, rules: .nineByNine, at: (8, 0), value: 9,
                       .nakedSingle(reasonUnits: [.row(8), .column(0), .box(6)]))
    }

    func testNakedSingleInBox() throws {
        let text = "123000000 456000000 780000000" + String(repeating: " 000000000", count: 6)
        try assertHint(text, rules: .nineByNine, at: (2, 2), value: 9,
                       .nakedSingle(reasonUnits: [.row(2), .column(2), .box(0)]))
    }

    func testNakedSingleFiveByFive() throws {
        try assertHint("12340 00000 00000 00000 00000", rules: .fiveByFive, at: (0, 4), value: 5,
                       .nakedSingle(reasonUnits: [.row(0), .column(4)]))
    }

    // MARK: - 隐性唯一

    /// 第 0 行只有 (0,0) 能填 9。
    func testHiddenSingleInRow() throws {
        let text = "000000000 000900000 000000900 090000000 000090000 000000090 009000000 000009000 000000009"
        try assertHint(text, rules: .nineByNine, at: (0, 0), value: 9, .hiddenSingle(unit: .row(0)))
    }

    /// 第 3 列只有 (3,3) 能填 7；第 3 行中 7 仍有多个候选格。
    func testHiddenSingleInColumn() throws {
        let text = "000070000 000000000 000000000 000000003 000800000 700000000 000007000 000000000 000000000"
        try assertHint(text, rules: .nineByNine, at: (3, 3), value: 7, .hiddenSingle(unit: .column(3)))
    }

    /// 第 0 宫只有 (0,0) 能填 5；所在行、列中 5 都不唯一。
    func testHiddenSingleInBox() throws {
        let text = "030000010 000105000 190000000 000000000 000000000 000000000 000000000 000000000 005080000"
        try assertHint(text, rules: .nineByNine, at: (0, 0), value: 5, .hiddenSingle(unit: .box(0)))
    }

    /// 第 8 宫只有 (8,7) 能填 7。
    func testHiddenSingleInNonZeroBox() throws {
        let text = "000000000 000000000 000000000 050060000 000000700 000000000 000000084 007000000 000000009"
        try assertHint(text, rules: .nineByNine, at: (8, 7), value: 7, .hiddenSingle(unit: .box(8)))
    }

    /// 5×5 无宫：第 3 列只有 (4,3) 能填 2。
    func testHiddenSingleInColumnFiveByFive() throws {
        try assertHint("00040 00010 00200 20000 00000", rules: .fiveByFive, at: (4, 3), value: 2,
                       .hiddenSingle(unit: .column(3)))
    }

    // MARK: - 无提示场景

    func testNoHintOnEmptyGrids() {
        for rules in [Rules.fourByFour, .fiveByFive, .nineByNine] {
            XCTAssertNil(hint(in: Grid(rules: rules), rules: rules))
        }
    }

    func testNoHintOnCompletedGrid() throws {
        XCTAssertNil(hint(in: try makeGrid(size: 4, "1234 3412 2341 4123"), rules: .fourByFour))
    }

    func testNoHintWhenConflictsExist() throws {
        XCTAssertNil(hint(in: try makeGrid(size: 4, "1001 0000 0000 0000"), rules: .fourByFour))
    }

    /// 某格没有候选数时，盘面尚未出现直接冲突，但应返回 nil。
    func testNoHintWhenCellHasNoCandidates() throws {
        XCTAssertNil(hint(in: try makeGrid(size: 4, "0040 0000 3401 0023"), rules: .fourByFour))
    }

    // MARK: - 纯函数

    func testHintDoesNotMutateGrid() throws {
        let text = "003020600 900305001 001806400 008102900 700000008 006708200 002609500 800203009 005010300"
        let grid = try makeGrid(size: 9, text)
        let copy = grid
        _ = hint(in: grid, rules: .nineByNine)
        XCTAssertEqual(grid, copy)
    }

    // MARK: - 辅助

    private func makeGrid(size: Int, _ text: String) throws -> Grid {
        let cells = try text.filter { !$0.isWhitespace }.map { try XCTUnwrap($0.wholeNumberValue) }
        return try Grid(size: size, cells: cells)
    }

    private func assertHint(
        _ text: String,
        rules: Rules,
        at cell: (row: Int, column: Int),
        value: Int,
        _ technique: HintTechnique,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let grid = try makeGrid(size: rules.size, text)
        let result = try XCTUnwrap(hint(in: grid, rules: rules), file: file, line: line)
        XCTAssertEqual(result.target, CellIndex(row: cell.row, column: cell.column), file: file, line: line)
        XCTAssertEqual(result.value, value, file: file, line: line)
        if case let .nakedSingle(actual) = result.technique, case let .nakedSingle(expected) = technique {
            XCTAssertEqual(Set(actual), Set(expected), file: file, line: line)
        } else {
            XCTAssertEqual(result.technique, technique, file: file, line: line)
        }
    }
}
