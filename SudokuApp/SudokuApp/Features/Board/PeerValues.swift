/// 自动筛选用：找出某格所在行、列、宫里已经出现的数字。
///
/// 只在 App 层扫描同组格子，不调用引擎，开销是 O(size)。
/// 5×5 没有宫，只看行和列。格子自己的值不算在内，方便改写当前格。
enum PeerValues {
    static func used(in grid: Grid, rules: Rules, at cell: CellIndex) -> Set<Int> {
        let size = rules.size
        guard grid.size == size, (0 ..< size).contains(cell.row), (0 ..< size).contains(cell.column) else {
            return []
        }
        var values: Set<Int> = []
        for offset in 0 ..< size {
            if offset != cell.column {
                values.insert(grid[row: cell.row, column: offset])
            }
            if offset != cell.row {
                values.insert(grid[row: offset, column: cell.column])
            }
        }
        if let boxRows = rules.boxRows, let boxCols = rules.boxCols {
            let top = cell.row / boxRows * boxRows
            let left = cell.column / boxCols * boxCols
            for row in top ..< top + boxRows {
                for column in left ..< left + boxCols where row != cell.row || column != cell.column {
                    values.insert(grid[row: row, column: column])
                }
            }
        }
        values.remove(Grid.emptyCell)
        return values
    }
}
