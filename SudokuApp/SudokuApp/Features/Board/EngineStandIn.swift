/// 引擎接口的本地替身。
///
/// 字段对齐技术设计里的 Rules、Grid。方法名对齐即将冻结的
/// conflicts、solve、solutionCount。
/// 引擎合并进 main 之后，删掉这些类型，改为引用 SudokuEngine。
/// 棋盘只依赖 SudokuBoardEngine，替换时不用改视图。

/// 规则。5×5 的 boxRows、boxCols 为 nil，表示没有宫。
struct Rules: Equatable, Codable, Sendable {
    let size: Int
    let boxRows: Int?
    let boxCols: Int?

    /// 宫的行数和列数。没有宫时返回 nil，棋盘不画粗宫线。
    var boxSpan: (rows: Int, cols: Int)? {
        guard let boxRows, let boxCols, boxRows > 0, boxCols > 0 else {
            return nil
        }
        return (boxRows, boxCols)
    }
}

/// 棋盘。cells 长度是 size * size，0 表示空。
struct Grid: Equatable, Codable, Sendable {
    var cells: [Int]
}

/// 棋盘用到的引擎能力。冲突和求解都走这里，界面不要自己算。
protocol SudokuBoardEngine: Sendable {
    /// 需要标红的格子下标。哪些算冲突由引擎决定。
    func conflicts(in grid: Grid, rules: Rules) -> Set<Int>

    /// 求出一盘填满的棋盘。当前盘面没有解时返回 nil。
    func solve(_ grid: Grid, rules: Rules) -> Grid?

    /// 解的个数。调用方只区分 0、1 和更多。
    func solutionCount(_ grid: Grid, rules: Rules) -> Int
}
