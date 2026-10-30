/// 描述一个假设分支：对某个空格尝试一组候选数。
public struct Assumption: Codable, Equatable, Hashable, Sendable {
    /// 目标空格。
    public let target: CellIndex

    /// 可尝试的候选数，按升序排列。
    public let candidates: [Int]
}

/// 在当前盘面中选择最适合做假设的格子。
///
/// 若盘面已有冲突、已填满、任一空格没有候选数，或 `hint(in:rules:)` 能给出确定提示，
/// 则返回 `nil`；否则使用 MRV（Minimum Remaining Values）策略，选出候选数最少的空格，
/// 候选数相同时取行优先下标最小者，并返回该格及其升序候选数列表。
///
/// 支持 4×4、5×5（拉丁方，无宫约束）与 9×9 三种规格。
///
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。
public func bestAssumption(in grid: Grid, rules: Rules) -> Assumption? {
    precondition(grid.size == rules.size, "grid.size must equal rules.size")

    guard conflicts(in: grid, rules: rules).isEmpty else { return nil }
    guard grid.cells.contains(Grid.emptyCell) else { return nil }

    let layout = BoardLayout(rules: rules)
    let masks = candidateMasks(for: grid, layout: layout)

    for cell in grid.cells.indices where grid.cells[cell] == Grid.emptyCell {
        guard masks[cell] != 0 else { return nil }
    }

    guard hint(in: grid, rules: rules) == nil else { return nil }

    var bestCell: Int?
    var bestCount = Int.max
    for cell in grid.cells.indices where grid.cells[cell] == Grid.emptyCell {
        let count = masks[cell].nonzeroBitCount
        if count < bestCount {
            bestCell = cell
            bestCount = count
        }
    }

    guard let cell = bestCell else { return nil }

    var candidates: [Int] = []
    let mask = masks[cell]
    for bit in 0 ..< grid.size where mask & (1 << UInt16(bit)) != 0 {
        candidates.append(bit + 1)
    }

    return Assumption(
        target: CellIndex(linearIndex: cell, size: grid.size),
        candidates: candidates
    )
}
