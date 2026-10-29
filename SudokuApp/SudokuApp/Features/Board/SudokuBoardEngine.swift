/// 棋盘用到的引擎能力。三个方法的签名与冻结的 SudokuEngine 一致。
///
/// 接上真引擎时，适配器只转发 `conflicts`、`solve`、`solutionCount`，不做换算，也不要 `try!`。
/// 求解实现还是 `fatalError` 的时候不要接。
///
/// `conflicts` 是轻量同步调用，可以在主线程使用。
/// 三个方法都可能被并发调用。如果用类来实现，需要自己保证线程安全。
protocol SudokuBoardEngine: Sendable {
    func conflicts(in grid: Grid, rules: Rules) -> Set<CellIndex>

    func solve(_ grid: Grid, rules: Rules) -> Grid?

    /// `limit` 是最多计数。唯一性检查传 2：0 无解，1 唯一，2 表示至少两个。
    func solutionCount(_ grid: Grid, rules: Rules, limit: Int) -> Int
}
