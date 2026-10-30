import Foundation
@testable import SudokuApp
import XCTest

final class BoardModelTests: XCTestCase {
    func testRulesUseDesignFieldNames() throws {
        let rules = try Rules(size: 9, boxRows: 3, boxCols: 3)
        let rulesText = try jsonText(rules)
        XCTAssertTrue(rulesText.contains("\"size\":9"))
        XCTAssertTrue(rulesText.contains("\"boxRows\":3"))
        XCTAssertTrue(rulesText.contains("\"boxCols\":3"))

        let five = Rules.fiveByFive
        let fiveText = try jsonText(five)
        XCTAssertTrue(fiveText.contains("\"boxRows\":null"))
        XCTAssertTrue(fiveText.contains("\"boxCols\":null"))
        let decoded = try JSONDecoder().decode(Rules.self, from: Data(fiveText.utf8))
        XCTAssertEqual(decoded, five)

        let explicit = Data("{\"size\":5,\"boxRows\":null,\"boxCols\":null}".utf8)
        let fromNull = try JSONDecoder().decode(Rules.self, from: explicit)
        XCTAssertEqual(fromNull, five)
    }

    func testGridUsesCellsField() throws {
        let grid = try Grid(size: 4, cells: [0, 1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        let text = try jsonText(grid)
        XCTAssertTrue(text.contains("\"cells\""))
        XCTAssertTrue(text.contains("\"size\":4"))
        let decoded = try JSONDecoder().decode(Grid.self, from: Data(text.utf8))
        XCTAssertEqual(decoded, grid)
        XCTAssertEqual(grid.cells.first, Grid.emptyCell)
    }

    func testRulesInitializerRejectsUnsupportedShapes() throws {
        XCTAssertThrowsError(try Rules(size: 6, boxRows: 2, boxCols: 3)) { error in
            XCTAssertEqual(error as? Rules.ValidationError, .unsupportedSize(6))
        }
        XCTAssertThrowsError(try Rules(size: 5, boxRows: 1, boxCols: nil))
        XCTAssertThrowsError(try Rules(size: 0, boxRows: nil, boxCols: nil))
        let four = try Rules(size: 4, boxRows: 2, boxCols: 2)
        XCTAssertEqual(four, Rules.fourByFour)
    }

    func testGridRejectsMismatchedLength() {
        XCTAssertThrowsError(try Grid(size: 4, cells: [1])) { error in
            let expected = Grid.ValidationError.cellCountMismatch(expected: 16, actual: 1)
            XCTAssertEqual(error as? Grid.ValidationError, expected)
        }
        XCTAssertThrowsError(try Grid(size: 4, cells: Array(repeating: 8, count: 16)))
    }

    func testPresetsCoverPlayableSizes() {
        XCTAssertEqual(BoardPreset.allCases.map(\.title), ["4×4", "5×5", "9×9"])
        XCTAssertEqual(BoardPreset.four.rules, Rules.fourByFour)
        XCTAssertEqual(BoardPreset.five.rules, Rules.fiveByFive)
        XCTAssertEqual(BoardPreset.nine.rules, Rules.nineByNine)
        XCTAssertEqual(BoardPreset.five.detail, "拉丁方，无宫")
        XCTAssertNil(Rules.fiveByFive.boxRows)
        XCTAssertTrue(Rules.nineByNine.hasBoxes)
    }

    func testNineByNineBoxLines() {
        let rules = BoardPreset.nine.rules
        XCTAssertEqual(BoardLines.verticalWeight(line: 0, rules: rules), .frame)
        XCTAssertEqual(BoardLines.verticalWeight(line: 1, rules: rules), .hairline)
        XCTAssertEqual(BoardLines.verticalWeight(line: 2, rules: rules), .hairline)
        XCTAssertEqual(BoardLines.verticalWeight(line: 3, rules: rules), .box)
        XCTAssertEqual(BoardLines.verticalWeight(line: 6, rules: rules), .box)
        XCTAssertEqual(BoardLines.verticalWeight(line: 9, rules: rules), .frame)
        XCTAssertEqual(BoardLines.horizontalWeight(line: 3, rules: rules), .box)
        XCTAssertEqual(BoardLines.horizontalWeight(line: 4, rules: rules), .hairline)
    }

    func testFourByFourBoxLines() {
        let rules = BoardPreset.four.rules
        XCTAssertEqual(BoardLines.verticalWeight(line: 2, rules: rules), .box)
        XCTAssertEqual(BoardLines.horizontalWeight(line: 2, rules: rules), .box)
        XCTAssertEqual(BoardLines.verticalWeight(line: 1, rules: rules), .hairline)
    }

    func testFiveByFiveHasNoBoxLines() {
        let rules = BoardPreset.five.rules
        for line in 0 ... rules.size {
            XCTAssertNotEqual(BoardLines.verticalWeight(line: line, rules: rules), .box)
            XCTAssertNotEqual(BoardLines.horizontalWeight(line: line, rules: rules), .box)
        }
        XCTAssertEqual(BoardLines.verticalWeight(line: 0, rules: rules), .frame)
        XCTAssertEqual(BoardLines.verticalWeight(line: 1, rules: rules), .hairline)
    }

    func testRowAndColumnSpansAreIndependent() {
        XCTAssertEqual(BoardLines.weight(line: 3, size: 6, span: 3), .box)
        XCTAssertEqual(BoardLines.weight(line: 2, size: 6, span: 3), .hairline)
        XCTAssertEqual(BoardLines.weight(line: 2, size: 6, span: 2), .box)
        XCTAssertEqual(BoardLines.weight(line: 3, size: 6, span: 2), .hairline)
    }

    func testInvalidLineDoesNotCrash() {
        XCTAssertEqual(BoardLines.weight(line: 0, size: 0, span: nil), .hairline)
        XCTAssertEqual(BoardLines.weight(line: -1, size: 4, span: 2), .hairline)
    }

    func testCellLabelDescribesConflict() {
        let cell = BoardCellState(
            index: 1,
            row: 0,
            column: 1,
            value: 4,
            isGiven: true,
            isSelected: true,
            isConflict: true
        )
        XCTAssertEqual(cell.accessibilityLabel, "第 1 行第 2 列，数字 4，题目给定，冲突，已选中")
    }

    func testEmptyCellLabel() {
        let cell = BoardCellState(
            index: 4,
            row: 1,
            column: 0,
            value: 0,
            isGiven: false,
            isSelected: false,
            isConflict: false
        )
        XCTAssertEqual(cell.accessibilityLabel, "第 2 行第 1 列，空")
    }

    private func jsonText(_ value: some Encodable) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
