/// 「玩家自己做完」的只读判断。写入（换文案、收起试填层）在 BoardViewModel+Steps.swift 里。
extension BoardViewModel {
    /// 盘面填满、没有冲突，而且没有用过「全解」。
    var isPlayerCompleted: Bool {
        let isFull = !grid.cells.contains(Grid.emptyCell)
        return isFull && conflicts.isEmpty && !usedAutoSolve
    }
}
