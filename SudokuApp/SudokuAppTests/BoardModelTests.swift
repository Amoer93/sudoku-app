@testable import SudokuApp
import Foundation
import XCTest

final class BoardModelTests: XCTestCase {
    func testRulesUseDesignFieldNames() throws {
        let rules = Rules(size: 9, boxRows: 3, boxCols: 3)
        let rulesText = try jsonText(rules)
        XCTAssertTrue(rulesText.contains("\"size\":9"))
        XCTAssertTrue(rulesText.contains("\"boxRows\":3"))
        XCTAssertTrue(rulesText.contains("\"boxCols\":3"))

        let five = Rules(size: 5, boxRows: nil, boxCols: nil)
        let decoded = try JSONDecoder().decode(Rules.self, from: Data(try jsonText(five).utf8))
        XCTAssertEqual(decoded, five)

        // 显式写出 null，锁住字段名。合成 Codable 可能省略 nil，不能靠编码结果判断。
        let explicit = Data("{\"size\":5,\"boxRows\":null,\"boxCols\":null}".utf8)
        let fromNull = try JSONDecoder().decode(Rules.self, from: explicit)
        XCTAssertEqual(fromNull, five)
    }

    func testGridUsesCellsField() throws {
        let grid = Grid(cells: [0, 1, 2])
        let text = try jsonText(grid)
        XCTAssertTrue(text.contains("\"cells\""))
        let decoded = try JSONDecoder().decode(Grid.self, from: Data(text.utf8))
        XCTAssertEqual(decoded, grid)
    }

    func testBoxSpanFollowsOptionalBoxes() {
        let four = Rules(size: 4, boxRows: 2, boxCols: 2).boxSpan
        XCTAssertEqual(four?.rows, 2)
        XCTAssertEqual(four?.cols, 2)
        XCTAssertNil(Rules(size: 5, boxRows: nil, boxCols: nil).boxSpan)
        XCTAssertNil(Rules(size: 5, boxRows: 1, boxCols: nil).boxSpan)
        XCTAssertNil(Rules(size: 5, boxRows: 0, boxCols: 0).boxSpan)
    }

    func testPresetsCoverPlayableSizes() {
        XCTAssertEqual(BoardPreset.allCases.map(\.title), ["4×4", "5×5", "9×9"])
        XCTAssertEqual(BoardPreset.four.rules, Rules(size: 4, boxRows: 2, boxCols: 2))
        XCTAssertEqual(BoardPreset.five.rules, Rules(size: 5, boxRows: nil, boxCols: nil))
        XCTAssertEqual(BoardPreset.nine.rules, Rules(size: 9, boxRows: 3, boxCols: 3))
        XCTAssertEqual(BoardPreset.five.detail, "拉丁方，无宫")
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
        for line in 0...rules.size {
            XCTAssertNotEqual(BoardLines.verticalWeight(line: line, rules: rules), .box)
            XCTAssertNotEqual(BoardLines.horizontalWeight(line: line, rules: rules), .box)
        }
        XCTAssertEqual(BoardLines.verticalWeight(line: 0, rules: rules), .frame)
        XCTAssertEqual(BoardLines.verticalWeight(line: 1, rules: rules), .hairline)
    }

    func testRectangularBoxesUseDifferentSpans() {
        let rules = Rules(size: 6, boxRows: 2, boxCols: 3)
        XCTAssertEqual(BoardLines.verticalWeight(line: 3, rules: rules), .box)
        XCTAssertEqual(BoardLines.verticalWeight(line: 2, rules: rules), .hairline)
        XCTAssertEqual(BoardLines.horizontalWeight(line: 2, rules: rules), .box)
        XCTAssertEqual(BoardLines.horizontalWeight(line: 3, rules: rules), .hairline)
    }

    func testInvalidLineDoesNotCrash() {
        let rules = Rules(size: 0, boxRows: nil, boxCols: nil)
        XCTAssertEqual(BoardLines.verticalWeight(line: 0, rules: rules), .hairline)
        XCTAssertEqual(BoardLines.horizontalWeight(line: -1, rules: rules), .hairline)
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
