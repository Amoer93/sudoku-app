// 求解内核：候选数位掩码 + 约束传播（唯余） + 回溯（最少候选优先）。
// 只在包内使用，不属于公开接口。

/// 一张棋盘的约束结构：所有"单元"（行、列、宫）和每格的同伴格。
struct BoardLayout {
    let size: Int
    let units: [[Int]]
    let peers: [[Int]]

    /// 按规则建出行、列、宫三类单元，并算出每格的同伴。
    init(rules: Rules) {
        size = rules.size
        var allUnits = Self.rowUnits(size: rules.size) + Self.columnUnits(size: rules.size)
        if let boxRows = rules.boxRows, let boxCols = rules.boxCols {
            allUnits += Self.boxUnits(size: rules.size, boxRows: boxRows, boxCols: boxCols)
        }
        units = allUnits
        peers = Self.makePeers(cellCount: rules.cellCount, units: allUnits)
    }

    private static func rowUnits(size: Int) -> [[Int]] {
        var result: [[Int]] = []
        for row in 0 ..< size {
            result.append((0 ..< size).map { row * size + $0 })
        }
        return result
    }

    private static func columnUnits(size: Int) -> [[Int]] {
        var result: [[Int]] = []
        for column in 0 ..< size {
            result.append((0 ..< size).map { $0 * size + column })
        }
        return result
    }

    private static func boxUnits(size: Int, boxRows: Int, boxCols: Int) -> [[Int]] {
        var result: [[Int]] = []
        for top in stride(from: 0, to: size, by: boxRows) {
            for left in stride(from: 0, to: size, by: boxCols) {
                var box: [Int] = []
                for row in top ..< top + boxRows {
                    for column in left ..< left + boxCols {
                        box.append(row * size + column)
                    }
                }
                result.append(box)
            }
        }
        return result
    }

    /// 宫和行列会重叠，用集合去重，避免同一个同伴被重复消除。
    private static func makePeers(cellCount: Int, units: [[Int]]) -> [[Int]] {
        var peerSets = Array(repeating: Set<Int>(), count: cellCount)
        for unit in units {
            for cell in unit {
                peerSets[cell].formUnion(unit)
            }
        }
        var result: [[Int]] = []
        for cell in 0 ..< cellCount {
            peerSets[cell].remove(cell)
            result.append(peerSets[cell].sorted())
        }
        return result
    }
}

/// 搜索中的一个局面。每格一个位掩码：第 `value - 1` 位为 1 表示该数字仍可填。
/// 只剩一位的格子就是已确定的格子。值类型，回溯时直接复制。
struct SolverState {
    private(set) var candidates: [UInt16]
    private var pendingCells: [Int] = []

    /// 从棋盘建立局面并传播。已有数字互相冲突时返回 nil。
    init?(grid: Grid, layout: BoardLayout) {
        let allValues = UInt16((1 << layout.size) - 1)
        candidates = Array(repeating: allValues, count: grid.cells.count)
        for (cell, value) in grid.cells.enumerated() where value != Grid.emptyCell {
            candidates[cell] = 1 << UInt16(value - 1)
            pendingCells.append(cell)
        }
        if !propagate(layout: layout) {
            return nil
        }
    }

    /// 取出候选最少的未确定格。全部确定时返回 nil。
    func mostConstrainedCell() -> Int? {
        var bestCell: Int?
        var bestCount = Int.max
        for (cell, mask) in candidates.enumerated() {
            let count = mask.nonzeroBitCount
            if count > 1 && count < bestCount {
                bestCell = cell
                bestCount = count
                if count == 2 {
                    break // 不可能更少了，提前结束
                }
            }
        }
        return bestCell
    }

    /// 试填一个数字并传播。出现矛盾时返回 nil，原局面不变。
    func placing(value: Int, at cell: Int, layout: BoardLayout) -> SolverState? {
        var next = self
        next.candidates[cell] = 1 << UInt16(value - 1)
        next.pendingCells.append(cell)
        if next.propagate(layout: layout) {
            return next
        }
        return nil
    }

    /// 这一格还可填的数字，从小到大。
    func values(at cell: Int) -> [Int] {
        var result: [Int] = []
        let mask = candidates[cell]
        for bitIndex in 0 ..< UInt16.bitWidth {
            if mask & (1 << UInt16(bitIndex)) != 0 {
                result.append(bitIndex + 1)
            }
        }
        return result
    }

    /// 取出局面里每格的数字。只能在所有格子都确定后调用。
    func solvedCells() -> [Int] {
        candidates.map { $0.trailingZeroBitCount + 1 }
    }

    /// 把已确定格的数字从同伴里消除；消除后新变成单候选的格子继续排队。
    private mutating func propagate(layout: BoardLayout) -> Bool {
        while let cell = pendingCells.popLast() {
            let bit = candidates[cell]
            for peer in layout.peers[cell] {
                let before = candidates[peer]
                if before & bit == 0 {
                    continue
                }
                let after = before & ~bit
                if after == 0 {
                    return false // 同伴没有数字可填，或和已确定的格撞了
                }
                candidates[peer] = after
                if after.nonzeroBitCount == 1 {
                    pendingCells.append(peer)
                }
            }
        }
        return true
    }
}

/// 回溯搜索，最多找 `limit` 个解，按找到的顺序返回。
func findSolutions(in grid: Grid, rules: Rules, limit: Int) -> [Grid] {
    if limit <= 0 {
        return []
    }
    let layout = BoardLayout(rules: rules)
    guard let start = SolverState(grid: grid, layout: layout) else {
        return []
    }
    var found: [Grid] = []
    search(from: start, layout: layout, limit: limit, found: &found)
    return found
}

private func search(from state: SolverState, layout: BoardLayout, limit: Int, found: inout [Grid]) {
    guard let cell = state.mostConstrainedCell() else {
        appendSolution(state, layout: layout, to: &found)
        return
    }
    for value in state.values(at: cell) {
        if found.count >= limit {
            return
        }
        if let next = state.placing(value: value, at: cell, layout: layout) {
            search(from: next, layout: layout, limit: limit, found: &found)
        }
    }
}

private func appendSolution(_ state: SolverState, layout: BoardLayout, to found: inout [Grid]) {
    // 候选值都在 1...size 内，构造不会失败；失败说明内核有 bug，宁可丢掉也不返回坏解
    if let solved = try? Grid(size: layout.size, cells: state.solvedCells()) {
        found.append(solved)
    }
}
