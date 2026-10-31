/// 数独谜面规范指纹。同一等价类（几何对称 + 数字重标）的谜面共享同一个指纹。
public struct PuzzleFingerprint: Hashable, Codable, Sendable {
    public let value: String
    public init(value: String) { self.value = value }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// 数独谜面规范器。
public enum PuzzleCanonicalizer {
    /// 计算棋盘的规范指纹。当前仅支持 9x9 标准数独。
    public static func fingerprint(_ grid: Grid, rules: Rules) -> PuzzleFingerprint {
        precondition(rules == .nineByNine && grid.size == 9, "仅支持 9x9 标准数独")
        return PuzzleFingerprint(value: canonicalString(for: grid.cells))
    }
}
private let permutationsOfThree: [[Int]] = [
    [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]
]
private func canonicalString(for cells: [Int]) -> String {
    let grid = cells.map { UInt8($0) }
    var best = [UInt8](repeating: 9, count: 81)
    var candidate = [UInt8](repeating: 0, count: 81)
    let transposedGrid = transposed(grid)
    for transposedFlag in 0 ..< 2 {
        let source = transposedFlag == 1 ? transposedGrid : grid
        for bandPerm in permutationsOfThree {
            for rows0 in permutationsOfThree {
                for rows1 in permutationsOfThree {
                    for rows2 in permutationsOfThree {
                        let rows = permutedRows(source: source, bandPerm: bandPerm, rowPerms: [rows0, rows1, rows2])
                        searchStack(rows: rows, depth: 0, used: 0, state: SearchState(),
                                    best: &best, candidate: &candidate)
                    }
                }
            }
        }
    }
    return String(best.map { Character(Unicode.Scalar($0 + 48)) })
}
private func transposed(_ grid: [UInt8]) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: 81)
    for row in 0 ..< 9 {
        for column in 0 ..< 9 {
            result[column * 9 + row] = grid[row * 9 + column]
        }
    }
    return result
}
private func permutedRows(source: [UInt8], bandPerm: [Int], rowPerms: [[Int]]) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: 81)
    for newBand in 0 ..< 3 {
        let oldBand = bandPerm[newBand]
        for newRowInBand in 0 ..< 3 {
            let oldRowInBand = rowPerms[newBand][newRowInBand]
            let oldRow = oldBand * 3 + oldRowInBand
            let newRow = newBand * 3 + newRowInBand
            for column in 0 ..< 9 {
                result[newRow * 9 + column] = source[oldRow * 9 + column]
            }
        }
    }
    return result
}
/// 搜索状态：首行逐列确定列序，以首行前缀与当前最优比较做早期剪枝。
private struct SearchState {
    // 数字映射与列序都按 4 位打包进 UInt64，复制状态时无堆分配
    var map: UInt64 = 0
    var nextLabel: UInt64 = 1
    var better = false
    var pos = 0
    var columns: UInt64 = 0

    func column(at index: Int) -> Int { Int((columns >> UInt64(index * 4)) & 0xF) }
    mutating func setColumn(_ column: Int, at index: Int) { columns |= UInt64(column) << UInt64(index * 4) }
}

/// 递归选择列宫顺序与宫内列序（6 × 6^3 种），首行剪枝后再比较其余各行。
private func searchStack(
    rows: [UInt8], depth: Int, used: Int, state: SearchState,
    best: inout [UInt8], candidate: inout [UInt8]
) {
    if depth == 3 {
        finishRemainingRows(rows: rows, state: state, best: &best, candidate: &candidate)
        return
    }
    for originalStack in 0 ..< 3 where (used & (1 << originalStack)) == 0 {
        for columnPerm in permutationsOfThree {
            var next = state
            var pruned = false
            for index in 0 ..< 3 {
                let column = originalStack * 3 + columnPerm[index]
                next.setColumn(column, at: next.pos)
                if !place(rows[column], state: &next, best: best, candidate: &candidate) {
                    pruned = true
                    break
                }
            }
            if !pruned {
                searchStack(rows: rows, depth: depth + 1, used: used | (1 << originalStack),
                            state: next, best: &best, candidate: &candidate)
            }
        }
    }
}

/// 按已确定的列序处理第 2–9 行；若字典序更小则更新最优结果。
private func finishRemainingRows(
    rows: [UInt8], state: SearchState, best: inout [UInt8], candidate: inout [UInt8]
) {
    var state = state
    for row in 1 ..< 9 {
        for index in 0 ..< 9 {
            let value = rows[row * 9 + state.column(at: index)]
            if !place(value, state: &state, best: best, candidate: &candidate) { return }
        }
    }
    if state.better { best = candidate }
}

/// 写入一个重标号后的值；若已确定比当前最优大则返回 false（剪枝）。
private func place(
    _ value: UInt8, state: inout SearchState, best: [UInt8], candidate: inout [UInt8]
) -> Bool {
    var canon: UInt8 = 0
    if value != 0 {
        // 按首次出现顺序重标号
        let shift = UInt64(value) * 4
        var label = (state.map >> shift) & 0xF
        if label == 0 {
            label = state.nextLabel
            state.map |= label << shift
            state.nextLabel += 1
        }
        canon = UInt8(label)
    }
    candidate[state.pos] = canon
    if !state.better {
        if canon > best[state.pos] { return false }
        if canon < best[state.pos] { state.better = true }
    }
    state.pos += 1
    return true
}
