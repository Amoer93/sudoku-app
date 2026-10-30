/// 不依赖实例状态的下标工具。拆出来是为了让 BoardViewModel.swift 满足 SwiftLint 的长度限制。
extension BoardViewModel {
    static func linearSet(_ cells: Set<CellIndex>, size: Int) -> Set<Int> {
        var indexes: Set<Int> = []
        for cell in cells {
            indexes.insert(cell.linearIndex(size: size))
        }
        return indexes
    }

    static func givenIndexes(in grid: Grid) -> Set<Int> {
        var indexes: Set<Int> = []
        for (index, value) in grid.cells.enumerated() where value != Grid.emptyCell {
            indexes.insert(index)
        }
        return indexes
    }
}
