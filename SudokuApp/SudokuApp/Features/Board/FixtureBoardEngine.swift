/// 临时引擎。只认识 FixtureLibrary 里的题，按 Rules 匹配。
///
/// 冲突不是行列宫扫描，而是「和写死的答案不一样」。
/// 求解也不搜索，答案对得上就交回那盘答案。
/// 引擎接口合并后删掉这个类型，换成调用 SudokuEngine 的适配器。
struct FixtureBoardEngine: SudokuBoardEngine {
    var puzzles: [SamplePuzzle] = FixtureLibrary.all

    func conflicts(in grid: Grid, rules: Rules) -> Set<Int> {
        guard let solution = solution(matching: rules, grid: grid) else {
            return []
        }
        return mismatchedIndexes(in: grid, solution: solution)
    }

    func solve(_ grid: Grid, rules: Rules) -> Grid? {
        guard let solution = solution(matching: rules, grid: grid) else {
            return nil
        }
        if mismatchedIndexes(in: grid, solution: solution).isEmpty {
            return solution
        }
        return nil
    }

    func solutionCount(_ grid: Grid, rules: Rules) -> Int {
        if solve(grid, rules: rules) == nil {
            return 0
        }
        return 1
    }

    private func solution(matching rules: Rules, grid: Grid) -> Grid? {
        guard let puzzle = puzzles.first(where: { $0.rules == rules }) else {
            return nil
        }
        guard puzzle.solution.cells.count == grid.cells.count else {
            return nil
        }
        return puzzle.solution
    }

    /// 空格不算冲突。非空且不等于答案的格子要标红。
    private func mismatchedIndexes(in grid: Grid, solution: Grid) -> Set<Int> {
        guard grid.cells.count == solution.cells.count else {
            return []
        }
        var indexes: Set<Int> = []
        for (index, value) in grid.cells.enumerated() {
            let answer = solution.cells[index]
            if value != 0, value != answer {
                indexes.insert(index)
            }
        }
        return indexes
    }
}
