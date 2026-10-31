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
    for row in 0 ..< 9 {
        for column in 0 ..< 9 {
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
private func swapBands(_ grid: Grid, first: Int, second: Int) -> Grid {
    transformed(grid) { row, column in
        let band = row / 3
        let offset = row % 3
        let sourceRow = band == first ? second * 3 + offset : (band == second ? first * 3 + offset : row)
        return (sourceRow, column)
    }
}
private func swapStacks(_ grid: Grid, first: Int, second: Int) -> Grid {
    transformed(grid) { row, column in
        let stack = column / 3
        let offset = column % 3
        let sourceColumn = stack == first ? second * 3 + offset : (stack == second ? first * 3 + offset : column)
        return (row, sourceColumn)
    }
}
private func swapRowsInBand(_ grid: Grid, band: Int, first: Int, second: Int) -> Grid {
    transformed(grid) { row, column in
        let currentBand = row / 3
        let offset = row % 3
        let swapped = [first: second, second: first][offset, default: offset]
        let sourceOffset = currentBand == band ? swapped : offset
        return (currentBand * 3 + sourceOffset, column)
    }
}
private func swapColumnsInStack(_ grid: Grid, stack: Int, first: Int, second: Int) -> Grid {
    transformed(grid) { row, column in
        let currentStack = column / 3
        let offset = column % 3
        let swapped = [first: second, second: first][offset, default: offset]
        let sourceOffset = currentStack == stack ? swapped : offset
        return (row, currentStack * 3 + sourceOffset)
    }
}
private func relabel(_ grid: Grid, permutation: [Int]) -> Grid {
    var result = grid
    for row in 0 ..< 9 {
        for column in 0 ..< 9 {
            let value = result[row: row, column: column]
            if value != 0 {
                result[row: row, column: column] = permutation[value - 1]
            }
        }
    }
    return result
}
private func randomDigitPermutation(rng: inout FingerprintTestRNG) -> [Int] {
    var elements = Array(1 ... 9)
    for index in 0 ..< 9 {
        elements.swapAt(index, rng.int(in: index ..< 9))
    }
    return elements
}
private func randomComposedTransform(_ grid: Grid, rng: inout FingerprintTestRNG) -> Grid {
    var result = grid
    for _ in 0 ..< 10 {
        switch rng.int(in: 0 ..< 7) {
        case 0: result = transpose(result)
        case 1: result = hMirror(result)
        case 2: result = vMirror(result)
        case 3: result = swapBands(result, first: rng.int(in: 0 ..< 3), second: rng.int(in: 0 ..< 3))
        case 4: result = swapStacks(result, first: rng.int(in: 0 ..< 3), second: rng.int(in: 0 ..< 3))
        case 5: result = relabel(result, permutation: randomDigitPermutation(rng: &rng))
        case 6: result = swapRowsInBand(result, band: rng.int(in: 0 ..< 3), first: 0, second: 1)
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
    let solved = "123456789456789123789123456214365897365897214897214365531642978642978531978531642"
    grids += [Grid(rules: .nineByNine), try gridFrom(solved)]
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
            { swapBands($0, first: 0, second: 2) },
            { swapRowsInBand($0, band: 1, first: 0, second: 2) },
            { swapStacks($0, first: 0, second: 1) },
            { swapColumnsInStack($0, stack: 2, first: 0, second: 1) },
            { relabel($0, permutation: digitPerm) }
        ]
        for transform in transforms {
            XCTAssertEqual(PuzzleCanonicalizer.fingerprint(transform(grid), rules: .nineByNine), fingerprint)
        }
        var compositionRng = FingerprintTestRNG(seed: 42)
        for _ in 0 ..< 20 {
            let transformed = randomComposedTransform(grid, rng: &compositionRng)
            XCTAssertEqual(PuzzleCanonicalizer.fingerprint(transformed, rules: .nineByNine), fingerprint)
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
        XCTAssertTrue(fingerprint.value.allSatisfy { ("0" ... "9").contains($0) })
        XCTAssertEqual(fingerprint.value.first { $0 != "0" }, "1")
        let data = try JSONEncoder().encode(fingerprint)
        XCTAssertEqual(try JSONDecoder().decode(PuzzleFingerprint.self, from: data), fingerprint)
        let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        XCTAssertEqual(try XCTUnwrap(json as? String), fingerprint.value)
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
        // 耗时断言只在 release 下生效，debug/CI 下只打印
        #if !DEBUG
            XCTAssertLessThan(averageMs, 100.0)
        #endif
    }
    func testFingerprintIsIdempotent() throws {
        var grids = try allPuzzles()
        var rng = FingerprintTestRNG(seed: 20261101)
        for _ in 0 ..< 20 {
            let grid = try gridFrom(puzzles[rng.int(in: 0 ..< puzzles.count)])
            grids.append(randomComposedTransform(grid, rng: &rng))
        }
        #if DEBUG
            let sample = grids.prefix(4)
        #else
            let sample = grids.prefix(40)
        #endif
        for grid in sample {
            let fp = PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine)
            let digits = fp.value.compactMap { $0.wholeNumberValue }
            let grid2 = try Grid(size: 9, cells: digits)
            XCTAssertEqual(PuzzleCanonicalizer.fingerprint(grid2, rules: .nineByNine), fp)
        }
    }
    func testFingerprintMatchesExhaustiveSearch() throws {
        #if DEBUG
            throw XCTSkip("exhaustive 搜索在 debug 模式下过慢，仅在 release 下运行")
        #else
            let testGrids = try puzzles.prefix(3).map { try gridFrom($0) }
            for grid in testGrids {
                XCTAssertEqual(
                    PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine).value,
                    exhaustiveCanonicalString(for: grid)
                )
            }
        #endif
    }
}

#if !DEBUG
    private let referencePermutationsOfThree: [[Int]] = [
        [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]
    ]

    /// 穷举所有几何对称并首次出现重标号，作为 fingerprint 的参考实现。
    private func exhaustiveCanonicalString(for grid: Grid) -> String {
        let cells = grid.cells.map { UInt8($0) }
        var best = [UInt8](repeating: 9, count: 81)
        let perms = referencePermutationsOfThree
        let transposed = transposedCells(cells)
        for source in [cells, transposed] {
            for bandPerm in perms {
                for rows0 in perms {
                    for rows1 in perms {
                        for rows2 in perms {
                            let rowPerms = [rows0, rows1, rows2]
                            var rows = [UInt8](repeating: 0, count: 81)
                            for newBand in 0 ..< 3 {
                                let oldBand = bandPerm[newBand]
                                for newRowInBand in 0 ..< 3 {
                                    let oldRow = oldBand * 3 + rowPerms[newBand][newRowInBand]
                                    let newRow = newBand * 3 + newRowInBand
                                    for col in 0 ..< 9 { rows[newRow * 9 + col] = source[oldRow * 9 + col] }
                                }
                            }
                            updateBest(for: rows, best: &best)
                        }
                    }
                }
            }
        }
        return String(best.map { Character(Unicode.Scalar($0 + 48)) })
    }

    /// 对固定行序枚举所有列宫/宫内列排列并更新最优。
    private func updateBest(for rows: [UInt8], best: inout [UInt8]) {
        let perms = referencePermutationsOfThree
        for stackPerm in perms {
            for cols0 in perms {
                for cols1 in perms {
                    for cols2 in perms {
                        let candidate = canonicalCandidate(
                            rows: rows, stackPerm: stackPerm, colPerms: [cols0, cols1, cols2]
                        )
                        if candidate.lexicographicallyPrecedes(best) { best = candidate }
                    }
                }
            }
        }
    }

    private func transposedCells(_ cells: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 81)
        for row in 0 ..< 9 {
            for col in 0 ..< 9 { result[col * 9 + row] = cells[row * 9 + col] }
        }
        return result
    }

    private func canonicalCandidate(rows: [UInt8], stackPerm: [Int], colPerms: [[Int]]) -> [UInt8] {
        var candidate = [UInt8](repeating: 0, count: 81)
        var map = [UInt8](repeating: 0, count: 10)
        var nextLabel: UInt8 = 1
        var pos = 0
        for row in 0 ..< 9 {
            for colIndex in 0 ..< 9 {
                let stack = colIndex / 3
                let sourceCol = stackPerm[stack] * 3 + colPerms[stack][colIndex % 3]
                let value = rows[row * 9 + sourceCol]
                var canon: UInt8 = 0
                if value != 0 {
                    if map[Int(value)] == 0 { map[Int(value)] = nextLabel; nextLabel += 1 }
                    canon = map[Int(value)]
                }
                candidate[pos] = canon
                pos += 1
            }
        }
        return candidate
    }
#endif
