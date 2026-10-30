/// 棋盘用到的引擎能力。三个方法的签名与冻结的 SudokuEngine 一致。
///
/// 真引擎通过 `EngineBoardAdapter` 接入：用 `try?` 把 App 的 `Rules`/`Grid` 转成引擎类型再转发，不用 `try!`。
/// App 默认用 `EngineBoardAdapter`；`FixtureBoardEngine` 只留给测试和 SwiftUI 预览。
///
/// `conflicts` 是轻量同步调用，可以在主线程使用。
/// 三个方法都可能被并发调用。如果用类来实现，需要自己保证线程安全。
protocol SudokuBoardEngine: Sendable {
    func conflicts(in grid: Grid, rules: Rules) -> Set<CellIndex>

    func solve(_ grid: Grid, rules: Rules) -> Grid?

    /// `limit` 是最多计数。唯一性检查传 2：0 无解，1 唯一，2 表示至少两个。
    func solutionCount(_ grid: Grid, rules: Rules, limit: Int) -> Int

    /// 下一个确定格的位置（裸单或隐性唯一）。只给位置，不给数字；找不到返回 nil。
    func hintCell(in grid: Grid, rules: Rules) -> CellIndex?

    /// 没有确定格时，推荐一个适合假设的格子和它的候选数；找不到返回 nil。
    func assumptionCell(in grid: Grid, rules: Rules) -> BoardAssumption?
}

/// 推荐假设的格子和可以试的候选数（升序）。
struct BoardAssumption: Equatable, Sendable {
    let cell: CellIndex
    let candidates: [Int]
}

extension SudokuBoardEngine {
    /// 默认没有提示能力，替身和测试引擎不用各自实现。
    func hintCell(in _: Grid, rules _: Rules) -> CellIndex? {
        nil
    }

    /// 默认没有假设推荐能力，替身和测试引擎不用各自实现。
    func assumptionCell(in _: Grid, rules _: Rules) -> BoardAssumption? {
        nil
    }
}
