/// 解的数量分类，用于校验导入题目（如拍照识别）时快速判断是否有解、唯一解或多解。
public enum SolutionKind: Codable, Equatable, Hashable, Sendable {
    /// 无解。
    ///
    /// 不区分“已填格存在冲突”与“已填格无冲突但无法完成求解”这两种情况；
    /// 调用方如需区分，应额外调用 `conflicts(in:rules:)` 检查已填格冲突。
    case noSolution
    /// 唯一解。
    case unique
    /// 至少两个解。
    case multiple
}

/// 判断 `grid` 在 `rules` 下的解数量类别。
///
/// 复用 `solutionCount(_:rules:limit:)`，最多搜索到 2 个解：0 个返回 `.noSolution`，
/// 1 个返回 `.unique`，2 个及以上返回 `.multiple`。
///
/// 返回 `.noSolution` 时，仅表示求解器未找到解，不区分已填格是否冲突；
/// 调用方如需区分“已填格冲突”与“无冲突但无解”，应使用 `conflicts(in:rules:)` 另行判断。
///
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。
public func solutionKind(_ grid: Grid, rules: Rules) -> SolutionKind {
    switch solutionCount(grid, rules: rules, limit: 2) {
    case 0:
        return .noSolution
    case 1:
        return .unique
    default:
        return .multiple
    }
}
