@testable import SudokuApp
import SwiftUI
import XCTest

/// 蒙版底色、色板循环和候选数的测试。
@MainActor
final class MaskTintTests: XCTestCase {
    func testPaletteCyclesEveryFiveLayers() {
        for depth in 1 ... 5 {
            XCTAssertEqual(
                AssumptionLayerStyle.style(forDepth: depth),
                AssumptionLayerStyle.style(forDepth: depth + 5)
            )
        }
        XCTAssertNotEqual(AssumptionLayerStyle.style(forDepth: 1), AssumptionLayerStyle.style(forDepth: 2))
    }

    func testTintIsNilAtDepthZero() {
        XCTAssertNil(AssumptionLayerStyle.tintColor(forDepth: 0))
    }

    func testTintHueMatchesDigitHue() {
        for depth in 1 ... 10 {
            let style = AssumptionLayerStyle.style(forDepth: depth)
            let expected = style?.name.swiftUIColor.opacity(AssumptionLayerStyle.tintOpacity)
            XCTAssertEqual(AssumptionLayerStyle.tintColor(forDepth: depth), expected)
        }
    }

    func testTintOpacityRange() {
        XCTAssertTrue((0.12 ... 0.18).contains(AssumptionLayerStyle.tintOpacity))
    }

    func testEmptyCellCandidatesExcludePeers() throws {
        let rules = try Rules(size: 5, boxRows: nil, boxCols: nil)
        var grid = Grid(rules: rules)
        grid[row: 0, column: 1] = 2
        grid[row: 3, column: 0] = 4
        let result = BoardViewModel.candidates(for: 0, in: grid, rules: rules)
        XCTAssertEqual(result, [1, 3, 5])
    }

    func testFilledCellHasNoCandidates() throws {
        let rules = try Rules(size: 5, boxRows: nil, boxCols: nil)
        var grid = Grid(rules: rules)
        grid[row: 0, column: 0] = 3
        XCTAssertTrue(BoardViewModel.candidates(for: 0, in: grid, rules: rules).isEmpty)
        XCTAssertTrue(BoardViewModel.candidates(for: 99, in: grid, rules: rules).isEmpty)
    }

    func testCopyConstant() {
        XCTAssertEqual(BoardCopy.showCandidates, "显示候选数")
    }
}
