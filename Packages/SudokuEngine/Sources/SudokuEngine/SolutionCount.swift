/// 解的数量分类，用于校验导入题目（如拍照识别）时快速判断是否有解、唯一解或多解。
public enum SolutionCount: Codable, Equatable, Hashable, Sendable {
    /// 无解或已填格存在冲突。
    case none
    /// 唯一解。
    case unique
    /// 至少两个解。
    case multiple
}

/// 判断 `grid` 在 `rules` 下的解数量类别。
///
/// 复用 `solutionCount(_:rules:limit:)`，最多搜索到 2 个解：0 个返回 `.none`，
/// 1 个返回 `.unique`，2 个及以上返回 `.multiple`。
///
/// 已填格冲突时返回 `.none`（现有求解内核已保证输入冲突时计数为 0）。
///
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。
public func solutionCount(_ grid: Grid, rules: Rules) -> SolutionCount {
    switch solutionCount(grid, rules: rules, limit: 2) {
    case 0:
        return .none
    case 1:
        return .unique
    default:
        return .multiple
    }
}
