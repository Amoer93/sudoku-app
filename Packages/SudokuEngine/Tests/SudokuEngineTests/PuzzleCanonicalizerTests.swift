import Foundation
import SudokuEngine
import XCTest

struct FingerprintTestRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
    mutating func int(in range: Range<Int>) -> Int {
        Int(next() % UInt64(range.count)) + range.lowerBound
    }
}
private func gridFrom(_ string: String) throws -> Grid {
    try Grid(size: 9, cells: string.compactMap { $0.wholeNumberValue })
}
private func transformed(_ grid: Grid, mapping: (Int, Int) -> (Int, Int)) -> Grid {
    var result = Grid(rules: .nineByNine)
    for row in 0..<9 {
        for column in 0..<9 {
            let (sourceRow, sourceColumn) = mapping(row, column)
            result[row: row, column: column] = grid[row: sourceRow, column: sourceColumn]
        }
    }
    return result
}
private func transpose(_ grid: Grid) -> Grid { transformed(grid) { ($1, $0) } }
private func rotate90(_ grid: Grid) -> Grid { transformed(grid) { (8 - $1, $0) } }
private func rotate180(_ grid: Grid) -> Grid { transformed(grid) { (8 - $0, 8 - $1) } }
private func rotate270(_ grid: Grid) -> Grid { transformed(grid) { ($1, 8 - $0) } }
private func hMirror(_ grid: Grid) -> Grid { transformed(grid) { (8 - $0, $1) } }
private func vMirror(_ grid: Grid) -> Grid { transformed(grid) { ($0, 8 - $1) } }
private func swapBands(_ grid: Grid, a: Int, b: Int) -> Grid {
    transformed(grid) { row, column in
        let band = row / 3
        let offset = row % 3
        let sourceRow = band == a ? b * 3 + offset : (band == b ? a * 3 + offset : row)
        return (sourceRow, column)
    }
}
private func swapStacks(_ grid: Grid, a: Int, b: Int) -> Grid {
    transformed(grid) { row, column in
        let stack = column / 3
        let offset = column % 3
        let sourceColumn = stack == a ? b * 3 + offset : (stack == b ? a * 3 + offset : column)
        return (row, sourceColumn)
    }
}
private func swapRowsInBand(_ grid: Grid, band: Int, a: Int, b: Int) -> Grid {
    transformed(grid) { row, column in
        let currentBand = row / 3
        let offset = row % 3
        let sourceOffset = currentBand == band ? (offset == a ? b : (offset == b ? a : offset)) : offset
        return (currentBand * 3 + sourceOffset, column)
    }
}
private func swapColumnsInStack(_ grid: Grid, stack: Int, a: Int, b: Int) -> Grid {
    transformed(grid) { row, column in
        let currentStack = column / 3
        let offset = column % 3
        let sourceOffset = currentStack == stack ? (offset == a ? b : (offset == b ? a : offset)) : offset
        return (row, currentStack * 3 + sourceOffset)
    }
}
private func relabel(_ grid: Grid, permutation: [Int]) -> Grid {
    var result = grid
    for row in 0..<9 {
        for column in 0..<9 {
            let value = result[row: row, column: column]
            if value != 0 {
                result[row: row, column: column] = permutation[value - 1]
            }
        }
    }
    return result
}
private func randomDigitPermutation(rng: inout FingerprintTestRNG) -> [Int] {
    var elements = Array(1...9)
    for index in 0..<9 {
        elements.swapAt(index, rng.int(in: index..<9))
    }
    return elements
}
private func randomComposedTransform(_ grid: Grid, rng: inout FingerprintTestRNG) -> Grid {
    var result = grid
    for _ in 0..<10 {
        switch rng.int(in: 0..<7) {
        case 0: result = transpose(result)
        case 1: result = hMirror(result)
        case 2: result = vMirror(result)
        case 3: result = swapBands(result, a: rng.int(in: 0..<3), b: rng.int(in: 0..<3))
        case 4: result = swapStacks(result, a: rng.int(in: 0..<3), b: rng.int(in: 0..<3))
        case 5: result = relabel(result, permutation: randomDigitPermutation(rng: &rng))
        case 6: result = swapRowsInBand(result, band: rng.int(in: 0..<3), a: 0, b: 1)
        default: break
        }
    }
    return result
}
private let puzzles = [
    "501080000030000000000010007020050780085300090600000003010600800050001070900020064",
    "100007000000206308007000200041000709020008000000600050000900000000080001304000600",
    "600028010340060500000000600090000030000805070000600480052000300000000701003010000",
    "703000008080002000006703500800010040090020080060900023030400010450009000000000000",
    "000451000000006007005000060100500200300040009094000800000000043040390602700800000",
    "800000000003600000070090200050007000000045700000100030001000068008500010090000400"
]
private func allPuzzles() throws -> [Grid] {
    var grids = try puzzles.map { try gridFrom($0) }
    var rng = FingerprintTestRNG(seed: 2026)
    for puzzle in puzzles {
        let grid = try gridFrom(puzzle)
        grids += [transpose(grid), relabel(grid, permutation: randomDigitPermutation(rng: &rng))]
    }
    grids += [Grid(rules: .nineByNine), try gridFrom("123456789456789123789123456214365897365897214897214365531642978642978531978531642")]
    return grids
}
final class PuzzleCanonicalizerTests: XCTestCase {
    func testFingerprintInvariantUnderTransforms() throws {
        let grid = try gridFrom(puzzles[0])
        let fingerprint = PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine)
        var rng = FingerprintTestRNG(seed: 12345)
        let digitPerm = randomDigitPermutation(rng: &rng)
        let transforms: [(Grid) -> Grid] = [
            transpose, rotate90, rotate180, rotate270, hMirror, vMirror,
            { swapBands($0, a: 0, b: 2) },
            { swapRowsInBand($0, band: 1, a: 0, b: 2) },
            { swapStacks($0, a: 0, b: 1) },
            { swapColumnsInStack($0, stack: 2, a: 0, b: 1) },
            { relabel($0, permutation: digitPerm) }
        ]
        for transform in transforms {
            XCTAssertEqual(PuzzleCanonicalizer.fingerprint(transform(grid), rules: .nineByNine), fingerprint)
        }
        var compositionRng = FingerprintTestRNG(seed: 42)
        for _ in 0..<20 {
            XCTAssertEqual(PuzzleCanonicalizer.fingerprint(randomComposedTransform(grid, rng: &compositionRng), rules: .nineByNine), fingerprint)
        }
    }
    func testDifferentPuzzlesHaveDifferentFingerprints() throws {
        let fingerprints = try puzzles.map { PuzzleCanonicalizer.fingerprint(try gridFrom($0), rules: .nineByNine) }
        XCTAssertEqual(Set(fingerprints).count, fingerprints.count)
        var modified = try gridFrom(puzzles[0])
        modified[row: 0, column: 0] = modified[row: 0, column: 0] == 1 ? 2 : 1
        XCTAssertNotEqual(PuzzleCanonicalizer.fingerprint(modified, rules: .nineByNine), fingerprints[0])
    }
    func testFingerprintFormatDeterminismAndCodable() throws {
        let grid = try gridFrom(puzzles[0])
        let fingerprint = PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine)
        XCTAssertEqual(fingerprint, PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine))
        XCTAssertEqual(fingerprint.value.count, 81)
        XCTAssertTrue(fingerprint.value.allSatisfy { ("0"..."9").contains($0) })
        XCTAssertEqual(fingerprint.value.first { $0 != "0" }, "1")
        let data = try JSONEncoder().encode(fingerprint)
        XCTAssertEqual(try JSONDecoder().decode(PuzzleFingerprint.self, from: data), fingerprint)
        XCTAssertEqual(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? String), fingerprint.value)
    }
    func testFingerprintPerformance() throws {
        let grids = try allPuzzles()
        var totalNanoseconds: UInt64 = 0
        for grid in grids {
            let start = DispatchTime.now().uptimeNanoseconds
            _ = PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine)
            totalNanoseconds &+= DispatchTime.now().uptimeNanoseconds - start
        }
        let averageMs = Double(totalNanoseconds) / Double(grids.count) / 1_000_000.0
        print("Average fingerprint time: \(averageMs) ms over \(grids.count) puzzles")
        #if DEBUG
        XCTAssertLessThan(averageMs, 2000.0)
        #else
        XCTAssertLessThan(averageMs, 100.0)
        #endif
    }
}
