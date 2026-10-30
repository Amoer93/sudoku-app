/// 替身引擎，只给测试和 SwiftUI 预览用，App 默认不用它。只认识 FixtureLibrary 里的题，按 Rules 匹配。
///
/// 冲突不是行列宫扫描，而是「和写死的答案不一样」。
/// 求解也不搜索，答案对得上就交回那盘答案。
/// 解的个数最多计到 `limit`：对得上是 1，对不上是 0。`limit` 为 0 时直接返回 0。
/// 保留它是为了让测试和预览不依赖真求解，结果可预期。
struct FixtureBoardEngine: SudokuBoardEngine {
    var puzzles: [SamplePuzzle] = FixtureLibrary.all

    func conflicts(in grid: Grid, rules: Rules) -> Set<CellIndex> {
        guard let solution = solution(matching: rules, grid: grid) else {
            return []
        }
        return mismatchedCells(in: grid, solution: solution)
    }

    func solve(_ grid: Grid, rules: Rules) -> Grid? {
        guard let solution = solution(matching: rules, grid: grid) else {
            return nil
        }
        if mismatchedCells(in: grid, solution: solution).isEmpty {
            return solution
        }
        return nil
    }

    func solutionCount(_ grid: Grid, rules: Rules, limit: Int) -> Int {
        if limit <= 0 {
            return 0
        }
        if solve(grid, rules: rules) == nil {
            return 0
        }
        return min(1, limit)
    }

    private func solution(matching rules: Rules, grid: Grid) -> Grid? {
        guard grid.size == rules.size else {
            return nil
        }
        guard let puzzle = puzzles.first(where: { $0.rules == rules }) else {
            return nil
        }
        guard puzzle.solution.size == grid.size else {
            return nil
        }
        return puzzle.solution
    }

    /// 空格不算冲突。非空且不等于答案的格子要标红。
    private func mismatchedCells(in grid: Grid, solution: Grid) -> Set<CellIndex> {
        guard grid.size == solution.size, grid.cells.count == solution.cells.count else {
            return []
        }
        var cells: Set<CellIndex> = []
        for (offset, value) in grid.cells.enumerated() where value != Grid.emptyCell {
            guard value != solution.cells[offset] else {
                continue
            }
            cells.insert(CellIndex(linearIndex: offset, size: grid.size))
        }
        return cells
    }
}
