// 格子、撤销和求解的具体步骤。拆出来是为了让 BoardViewModel.swift 保持在长度限制以内。
// 这些步骤会写盘面状态，所以主类型里的部分存储属性要放宽到 internal 可写。

import Observation

/// 唯一性检查最多数到 2：0 无解，1 唯一，2 表示至少还有另一个解。
private let solutionCountLimit = 2

/// 一次离线求解的结果。计数针对求解前的盘面，不是填满之后的那一盘。
struct SolveOutcome: Sendable {
    let grid: Grid?
    let count: Int
}

/// 对求解前的当前盘面（给定数字 + 玩家填入）计数。不要把填满的结果再送进 `solutionCount`，否则多解题会变成 1。
private func makeSolveOutcome(
    engine: any SudokuBoardEngine,
    grid: Grid,
    rules: Rules
) -> SolveOutcome {
    let solved = engine.solve(grid, rules: rules)
    let count = engine.solutionCount(grid, rules: rules, limit: solutionCountLimit)
    return SolveOutcome(grid: solved, count: count)
}

/// 格子、撤销和求解的具体步骤。拆出来是为了让主类型保持短小。
extension BoardViewModel {
    /// 没有确定格时改为推荐一个假设格；只选中并高亮，不改盘面。
    func showAssumption() {
        guard let assumption = engine.assumptionCell(in: grid, rules: rules) else {
            hintedIndex = nil
            notice = .noHint
            return
        }
        // 先检查行列范围，因为 linearIndex 越界会直接崩溃
        let cell = assumption.cell
        let size = rules.size
        guard (0 ..< size).contains(cell.row), (0 ..< size).contains(cell.column) else {
            hintedIndex = nil
            notice = .noHint
            return
        }
        // 行列都在范围内，线性下标必然落在盘面内
        let index = cell.linearIndex(size: size)
        selectedIndex = index
        hintedIndex = index
        notice = .assumption(assumption.candidates)
    }

    /// 撤销退到某层开层点之前时，这一层已经不存在，要把它弹掉（嵌套的层也一样）。
    /// 重做越过开层点时不会重建这一层，所以重做回来的数字沿用快照里的层深。
    func dropLayersBeyondUndo() {
        while let top = layers.last, top.undoCount > undoStack.count {
            layers.removeLast()
        }
    }

    /// 清空和自动解题会改动整盘，假设层不再有意义：全部丢掉，数字都算确定数字。
    func clearAllLayers() {
        layers.removeAll()
        cellDepths = Array(repeating: 0, count: cellDepths.count)
    }

    /// 撤销/重做恢复的层深可能比当前层数大（那一层已被清空或弹掉），压回当前层数避免出现幽灵层。
    func clampDepthsToLayers() {
        let limit = layers.count
        for index in cellDepths.indices where cellDepths[index] > limit {
            cellDepths[index] = limit
        }
    }

    /// 变了的格子记成当前层；被清空的格子回到 0 层。
    func retagDepths(since before: Grid) {
        for index in grid.cells.indices where grid.cells[index] != before.cells[index] {
            if grid.cells[index] == Grid.emptyCell {
                cellDepths[index] = 0
            } else {
                cellDepths[index] = layers.count
            }
        }
    }

    /// 玩家自己做完时换成祝贺文案。试填层里做完也算，所以顺便把层收掉。
    func updatePlayerCompletion() {
        guard isPlayerCompleted else {
            return
        }
        notice = .playerCompleted
        clearAllLayers()
        guard !hasRecordedCompletion else {
            return
        }
        hasRecordedCompletion = true
        onPlayerCompleted?()
    }

    func pushUndo() {
        undoStack.append(snapshot())
        redoStack.removeAll()
    }

    func move(from source: inout [BoardSnapshot], onto destination: inout [BoardSnapshot]) {
        guard !isSolving, let replacement = source.popLast() else {
            return
        }
        destination.append(snapshot())
        grid = replacement.grid
        cellDepths = replacement.depths
        clampDepthsToLayers()
        refreshConflicts()
        notice = .idle
        updatePlayerCompletion()
        scheduleSolutionCount()
    }

    func beginSolve() -> Bool {
        guard !isSolving else {
            return false
        }
        isSolving = true
        notice = .idle
        return true
    }

    func fetchOutcome(for snapshot: Grid) async -> SolveOutcome {
        let activeRules = rules
        return await Task.detached { [engine] in
            makeSolveOutcome(engine: engine, grid: snapshot, rules: activeRules)
        }.value
    }

    func apply(_ outcome: SolveOutcome) {
        isSolving = false
        solutionCount = outcome.count
        guard let solved = outcome.grid else {
            notice = .unsolvable
            return
        }
        usedAutoSolve = true
        if solved != grid {
            let before = grid
            pushUndo()
            grid = solved
            retagDepths(since: before)
            refreshConflicts()
        }
        clearAllLayers()
        notice = .autoSolved
    }

    static func countSolutions(
        engine: any SudokuBoardEngine,
        grid: Grid,
        rules: Rules
    ) async -> Int {
        await Task.detached {
            engine.solutionCount(grid, rules: rules, limit: solutionCountLimit)
        }.value
    }
}
