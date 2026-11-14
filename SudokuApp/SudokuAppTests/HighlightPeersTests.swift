@testable import SudokuApp
import XCTest

/// 「高亮行列宫」：同行、同列、同宫下标和开关行为。
@MainActor
final class HighlightPeersTests: XCTestCase {
    func testNineByNineCenterCellHasTwentyPeers() {
        // 第 4 行第 4 列，下标 40，在中间的宫
        let peers = BoardViewModel.highlightedIndices(selected: 40, rules: .nineByNine)
        var expected: Set<Int> = []
        for offset in 0 ..< 9 {
            expected.insert(4 * 9 + offset)
            expected.insert(offset * 9 + 4)
        }
        for row in 3 ... 5 {
            for column in 3 ... 5 {
                expected.insert(row * 9 + column)
            }
        }
        expected.remove(40)
        XCTAssertEqual(peers.count, 20)
        XCTAssertEqual(peers, expected)
        XCTAssertFalse(peers.contains(40))
    }

    func testCornerCellBoxIsTopLeft() {
        let peers = BoardViewModel.highlightedIndices(selected: 0, rules: .nineByNine)
        XCTAssertEqual(peers.count, 20)
        XCTAssertTrue(peers.contains(10))
        XCTAssertTrue(peers.contains(20))
        XCTAssertFalse(peers.contains(30))
    }

    func testNoSelectionOrOutOfRangeIsEmpty() {
        XCTAssertTrue(BoardViewModel.highlightedIndices(selected: nil, rules: .nineByNine).isEmpty)
        XCTAssertTrue(BoardViewModel.highlightedIndices(selected: 81, rules: .nineByNine).isEmpty)
        XCTAssertTrue(BoardViewModel.highlightedIndices(selected: -1, rules: .nineByNine).isEmpty)
    }

    func testFiveByFiveUsesRowAndColumnOnly() {
        let peers = BoardViewModel.highlightedIndices(selected: 12, rules: .fiveByFive)
        XCTAssertEqual(peers.count, 8)
    }

    func testToggleOffSetsNoFlags() {
        let model = BoardViewModel(title: "t", puzzle: FixtureLibrary.puzzle(for: .nine), engine: FixtureBoardEngine())
        model.select(index: 40)
        let off = model.cellStates(showingCandidates: false, highlightingPeers: false)
        XCTAssertFalse(off.contains { $0.isPeerHighlighted })
        let on = model.cellStates(showingCandidates: false, highlightingPeers: true)
        let flagged = on.filter { $0.isPeerHighlighted }.map { $0.index }
        XCTAssertEqual(Set(flagged), BoardViewModel.highlightedIndices(selected: 40, rules: model.rules))
        XCTAssertFalse(on[40].isPeerHighlighted)
    }

    func testCopyAndStorageDefaults() {
        XCTAssertEqual(BoardCopy.highlightPeers, "点亮相关格子")
        XCTAssertEqual(BoardCopy.highlightPeersHint, "打开后，和选中格子同一行、同一列、同一个小方块的格子会深一点。")
        XCTAssertEqual(BoardHighlightStyle.storageKey, "highlightPeers")
        XCTAssertTrue(BoardHighlightStyle.defaultEnabled)
        XCTAssertEqual(BoardHighlightStyle.peerOverlay, 0.10)
    }
}
