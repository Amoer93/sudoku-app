// P1 求解入口。算法内核在 SolverCore.swift。
// 三个函数都是纯函数，不修改入参。`grid.size` 必须等于 `rules.size`。

/// 找出当前盘面上所有参与冲突的格子。
///
/// 同一个非空数字在同一行、同一列，或（`rules.hasBoxes` 时）同一宫里出现不少于两次时，
/// 这些格子都算冲突。空格（`Grid.emptyCell`）不计入。纯函数，不修改入参。
///
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。
/// 复杂度目标：按行、列、宫各扫一遍，随格子数线性增长。9×9 远小于求解的 50ms 预算。
public func conflicts(in grid: Grid, rules: Rules) -> Set<CellIndex> {
    requireCompatible(grid: grid, rules: rules)
    let layout = BoardLayout(rules: rules)
    var conflicting = Set<CellIndex>()
    for unit in layout.units {
        // 按数字分组，同一数字出现两次以上的格子都算冲突
        var cellsByValue: [Int: [Int]] = [:]
        for cell in unit where grid.cells[cell] != Grid.emptyCell {
            cellsByValue[grid.cells[cell], default: []].append(cell)
        }
        for cells in cellsByValue.values where cells.count >= 2 {
            for cell in cells {
                conflicting.insert(CellIndex(linearIndex: cell, size: grid.size))
            }
        }
    }
    return conflicting
}

/// 求一个完整解。无解时返回 nil；有多个解时返回其中任意一个，不判断是否唯一。
///
/// 已填的格子保持不变。返回的棋盘每一格都是 `1...size`，并且没有冲突。
/// 输入本身已完整且合法时，返回同一盘面。输入已完整但不合法时返回 nil。
///
/// 算法：候选数用 `UInt16` 位掩码，先做约束传播，再回溯。
/// 回溯时优先展开候选最少的空格。
///
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。
/// 复杂度目标：标准 9×9 题目在 iPhone 上求解小于 50ms。
public func solve(_ grid: Grid, rules: Rules) -> Grid? {
    requireCompatible(grid: grid, rules: rules)
    return findSolutions(in: grid, rules: rules, limit: 1).first
}

/// 统计解的个数，最多计到 `limit` 后停止。
///
/// 返回值在 `0...limit`。实际解更多时返回 `limit`。
/// 唯一性检查使用 `limit` 为 2：0 表示无解，1 表示唯一解，2 表示至少两个解。
/// `limit` 小于等于 0 时返回 0，不搜索。
///
/// 计数规则与 `solve` 相同：已填格必须保留。完整且合法计为 1 个解，完整但不合法计为 0。
/// 纯函数，不修改入参。
///
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。`limit` 不设限制，负数按 0 处理。
/// 复杂度目标：与求解同级。`limit` 很小时（例如 2）在找到足够的解后立刻停止。
public func solutionCount(_ grid: Grid, rules: Rules, limit: Int) -> Int {
    requireCompatible(grid: grid, rules: rules)
    return findSolutions(in: grid, rules: rules, limit: limit).count
}

private func requireCompatible(grid: Grid, rules: Rules) {
    precondition(grid.size == rules.size, "grid.size must equal rules.size")
}
