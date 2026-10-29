import Foundation
import SudokuEngine
import XCTest

final class GridTests: XCTestCase {
    func testEmptyGridMatchesRules() {
        let grid = Grid(rules: .nineByNine)
        XCTAssertEqual(grid.size, 9)
        XCTAssertEqual(grid.cells, Array(repeating: Grid.emptyCell, count: 81))
        XCTAssertEqual(grid[row: 8, column: 8], Grid.emptyCell)
    }

    func testSubscriptIsRowMajorAndPreservesValueSemantics() throws {
        var grid = Grid(rules: .fourByFour)
        let index = CellIndex(row: 1, column: 2)
        grid[row: 1, column: 2] = 4
        XCTAssertEqual(grid[index], 4)
        XCTAssertEqual(grid.cells[index.linearIndex(size: 4)], 4)

        var copy = grid
        copy[row: 0, column: 0] = 1
        XCTAssertEqual(grid[row: 0, column: 0], Grid.emptyCell)
        XCTAssertNotEqual(copy, grid)

        grid[index] = Grid.emptyCell
        XCTAssertEqual(grid[row: 1, column: 2], Grid.emptyCell)
    }

    func testInitAcceptsAFullLegalRange() throws {
        var cells = Array(repeating: Grid.emptyCell, count: 16)
        cells[0] = 1
        cells[15] = 4
        let grid = try Grid(size: 4, cells: cells)
        XCTAssertEqual(grid[row: 0, column: 0], 1)
        XCTAssertEqual(grid[row: 3, column: 3], 4)
    }

    func testInitRejectsBadShapeBeforeBadValues() {
        XCTAssertThrowsError(try Grid(size: 2, cells: [0, 0, 0, 0])) { error in
            XCTAssertEqual(error as? Grid.ValidationError, .unsupportedSize(2))
        }
        XCTAssertThrowsError(try Grid(size: 5, cells: [0, 0])) { error in
            XCTAssertEqual(
                error as? Grid.ValidationError,
                .cellCountMismatch(expected: 25, actual: 2)
            )
        }
    }

    func testInitRejectsValuesOutsideZeroThroughSize() {
        var cells = Array(repeating: 0, count: 16)
        cells[3] = 5
        XCTAssertThrowsError(try Grid(size: 4, cells: cells)) { error in
            XCTAssertEqual(error as? Grid.ValidationError, .invalidCellValue(5, size: 4))
        }

        cells[3] = -1
        XCTAssertThrowsError(try Grid(size: 4, cells: cells)) { error in
            XCTAssertEqual(error as? Grid.ValidationError, .invalidCellValue(-1, size: 4))
        }
    }

    func testCodableRoundTrip() throws {
        var grid = Grid(rules: .fiveByFive)
        grid[row: 4, column: 1] = 5
        let data = try JSONEncoder().encode(grid)
        let decoded = try JSONDecoder().decode(Grid.self, from: data)
        XCTAssertEqual(decoded, grid)

        let raw = try JSONSerialization.jsonObject(with: data)
        let object = try XCTUnwrap(raw as? [String: Any])
        XCTAssertEqual(object["size"] as? Int, 5)
        let cells = try XCTUnwrap(object["cells"] as? [Int])
        XCTAssertEqual(cells[4 * 5 + 1], 5)
    }

    func testDecodingRejectsAShortGrid() {
        let data = Data(#"{"size":9,"cells":[0]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Grid.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
