/// 棋盘上的一格。行和列都从 0 开始。
///
/// 形状与 SudokuEngine 的 `CellIndex` 一致，适配器不用做下标换算。
struct CellIndex: Hashable, Codable, Sendable {
    let row: Int
    let column: Int

    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    /// 用行优先下标构造。`size > 0` 且下标在棋盘内，否则触发 precondition。
    init(linearIndex: Int, size: Int) {
        precondition(size > 0, "size must be > 0")
        precondition(
            linearIndex >= 0 && linearIndex < size * size,
            "linearIndex out of range"
        )
        row = linearIndex / size
        column = linearIndex % size
    }

    /// 转成 `Grid.cells` 的行优先下标。格不在该边长内时触发 precondition。
    func linearIndex(size: Int) -> Int {
        precondition(size > 0, "size must be > 0")
        precondition(
            row >= 0 && column >= 0 && row < size && column < size,
            "cell is outside the grid"
        )
        return row * size + column
    }
}
