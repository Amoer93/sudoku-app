import Foundation
import SudokuEngine
import XCTest

final class CellIndexTests: XCTestCase {
    func testLinearIndexRoundTrip() {
        let size = 4
        for row in 0 ..< size {
            for column in 0 ..< size {
                let index = CellIndex(row: row, column: column)
                let linearIndex = index.linearIndex(size: size)
                XCTAssertEqual(linearIndex, row * size + column)
                XCTAssertEqual(CellIndex(linearIndex: linearIndex, size: size), index)
            }
        }
    }

    func testEqualIndexesCollapseInASet() {
        let direct = CellIndex(row: 2, column: 3)
        let fromLinear = CellIndex(linearIndex: 2 * 9 + 3, size: 9)
        XCTAssertEqual(Set([direct, fromLinear]).count, 1)
    }

    func testCodableRoundTrip() throws {
        let index = CellIndex(row: 3, column: 1)
        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(CellIndex.self, from: data)
        XCTAssertEqual(decoded, index)

        let raw = try JSONSerialization.jsonObject(with: data)
        let object = try XCTUnwrap(raw as? [String: Any])
        XCTAssertEqual(object["row"] as? Int, 3)
        XCTAssertEqual(object["column"] as? Int, 1)
    }
}
