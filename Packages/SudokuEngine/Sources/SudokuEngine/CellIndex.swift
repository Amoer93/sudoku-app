/// 棋盘上的一格，行和列都从 0 开始。
///
/// 本身不检查是否落在某张棋盘内。和 `Grid` 一起使用时，行列必须在 `0..<size`。
/// 行优先下标是 `row * size + column`，与 `Grid.cells` 的顺序一致。
/// 编码键：`row`、`column`。
public struct CellIndex: Hashable, Codable, Sendable {
    /// 从 0 开始的行号。
    public let row: Int

    /// 从 0 开始的列号。
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    /// 用行优先下标构造。
    ///
    /// 前置条件：`size > 0`，且 `linearIndex` 在 `0..<size * size`。否则触发 precondition。
    public init(linearIndex: Int, size: Int) {
        precondition(size > 0, "size must be > 0")
        precondition(
            linearIndex >= 0 && linearIndex < size * size,
            "linearIndex out of range"
        )
        row = linearIndex / size
        column = linearIndex % size
    }

    /// 转成 `Grid.cells` 使用的行优先下标。
    ///
    /// 前置条件：`size > 0`，且这一格落在该边长内。否则触发 precondition。
    public func linearIndex(size: Int) -> Int {
        precondition(size > 0, "size must be > 0")
        precondition(
            row >= 0 && column >= 0 && row < size && column < size,
            "cell is outside the grid"
        )
        return row * size + column
    }
}
