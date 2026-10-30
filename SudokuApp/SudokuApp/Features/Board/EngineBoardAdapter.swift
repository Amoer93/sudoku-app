import SudokuEngine

/// 把 App 的 `Rules`/`Grid`/`CellIndex` 转成 SudokuEngine 的同名类型再转发。
///
/// 只做类型转换，不改坐标。转换失败（尺寸不支持、长度不对）一律按「无冲突 / 无解 / 0 个解」处理，
/// 不用 `try!`，也不会触发引擎的 `grid.size == rules.size` precondition。
///
/// 注意：引擎的求解函数目前还是 `fatalError("TODO")`，求解实现合并之前不要把它设成默认引擎。
struct EngineBoardAdapter: SudokuBoardEngine {
    func conflicts(in grid: Grid, rules: Rules) -> Set<CellIndex> {
        guard let (engineGrid, engineRules) = Self.convert(grid, rules) else {
            return []
        }
        let cells = SudokuEngine.conflicts(in: engineGrid, rules: engineRules)
        return Set(cells.map { CellIndex(row: $0.row, column: $0.column) })
    }

    func solve(_ grid: Grid, rules: Rules) -> Grid? {
        guard let (engineGrid, engineRules) = Self.convert(grid, rules),
              let solved = SudokuEngine.solve(engineGrid, rules: engineRules)
        else {
            return nil
        }
        return try? Grid(size: solved.size, cells: solved.cells)
    }

    func solutionCount(_ grid: Grid, rules: Rules, limit: Int) -> Int {
        guard limit > 0, let (engineGrid, engineRules) = Self.convert(grid, rules) else {
            return 0
        }
        return SudokuEngine.solutionCount(engineGrid, rules: engineRules, limit: limit)
    }

    /// 转换并校验 `grid.size == rules.size`、`cells.count == size * size`。失败返回 nil。
    static func convert(_ grid: Grid, _ rules: Rules) -> (SudokuEngine.Grid, SudokuEngine.Rules)? {
        guard grid.size == rules.size, grid.cells.count == rules.cellCount else {
            return nil
        }
        guard let engineRules = try? SudokuEngine.Rules(
            size: rules.size,
            boxRows: rules.boxRows,
            boxCols: rules.boxCols
        ),
            let engineGrid = try? SudokuEngine.Grid(size: grid.size, cells: grid.cells)
        else {
            return nil
        }
        return (engineGrid, engineRules)
    }
}
