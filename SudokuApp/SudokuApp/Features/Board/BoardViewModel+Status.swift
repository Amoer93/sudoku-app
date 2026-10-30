/// 只读的界面状态（按钮可用性、状态文案）。拆出来是为了让 BoardViewModel.swift 满足 SwiftLint 的长度限制。
/// 这里不写任何存储属性，所以不需要和主类型放在同一个文件。
extension BoardViewModel {
    var cellStates: [BoardCellState] {
        grid.cells.indices.map { index in
            state(at: index)
        }
    }

    var canUndo: Bool {
        !undoStack.isEmpty && !isSolving
    }

    var canRedo: Bool {
        !redoStack.isEmpty && !isSolving
    }

    var canClear: Bool {
        !isSolving && grid.cells.enumerated().contains { index, value in
            value != Grid.emptyCell && !givens.contains(index)
        }
    }

    /// 自动筛选时要禁用的数字。
    /// 关闭、没选格、选中给定格（整块键盘本来就禁用）时都返回空集合。
    var disabledValues: Set<Int> {
        guard isAutoFilterOn, let selectedIndex, !givens.contains(selectedIndex),
              let cell = cell(at: selectedIndex)
        else {
            return []
        }
        return PeerValues.used(in: grid, rules: rules, at: cell)
    }

    /// 自动筛选下，选中的空格 1 到 N 全被禁用，说明前面可能填错了。
    var hasNoCandidates: Bool {
        guard isAutoFilterOn, let selectedIndex, !givens.contains(selectedIndex),
              grid.cells.indices.contains(selectedIndex),
              grid.cells[selectedIndex] == Grid.emptyCell,
              rules.size > 0
        else {
            return false
        }
        return disabledValues.isSuperset(of: Set(1 ... rules.size))
    }

    var canEnter: Bool {
        guard !isSolving, let selectedIndex else {
            return false
        }
        return !givens.contains(selectedIndex)
    }

    var statusText: String {
        if isSolving {
            return BoardCopy.solving
        }
        if let text = notice.text {
            return text
        }
        if hasNoCandidates {
            return BoardCopy.noCandidates
        }
        return selectionHint
    }

    var statusIsWarning: Bool {
        if isSolving {
            return false
        }
        if notice.isWarning {
            return true
        }
        if notice == .idle, hasNoCandidates {
            return true
        }
        guard notice == .idle, let selectedIndex else {
            return false
        }
        return givens.contains(selectedIndex)
    }

    var solutionCountText: String {
        guard let solutionCount else {
            return BoardCopy.checkingSolutions
        }
        switch solutionCount {
        case 0:
            return BoardCopy.noSolution
        case 1:
            return BoardCopy.uniqueSolution
        default:
            return BoardCopy.multipleSolutions
        }
    }

    var solutionCountIsWarning: Bool {
        solutionCount == 0
    }
}

/// 只在本文件里用的只读小工具。
private extension BoardViewModel {
    var selectionHint: String {
        guard let selectedIndex else {
            return BoardCopy.selectCell
        }
        if givens.contains(selectedIndex) {
            return BoardCopy.givenLocked
        }
        return BoardCopy.enterDigit
    }
}

/// 只读的格子工具。主文件里的输入、清空等写入逻辑会用到。
extension BoardViewModel {
    func state(at index: Int) -> BoardCellState {
        let size = max(rules.size, 1)
        return BoardCellState(
            index: index,
            row: index / size,
            column: index % size,
            value: grid.cells[index],
            isGiven: givens.contains(index),
            isSelected: selectedIndex == index,
            isConflict: conflicts.contains(index),
            isHinted: hintedIndex == index,
            layerDepth: layerDepth(at: index),
            isAssumptionHint: hintedIndex == index && isHintAnAssumption
        )
    }

    func accepts(_ value: Int) -> Bool {
        if value == Grid.emptyCell {
            return true
        }
        guard rules.size > 0 else {
            return false
        }
        return (1 ... rules.size).contains(value)
    }

    func cell(at index: Int) -> CellIndex? {
        guard rules.size > 0, grid.cells.indices.contains(index) else {
            return nil
        }
        return CellIndex(linearIndex: index, size: rules.size)
    }

    /// 把所有玩家填的数字清掉后的盘面，不改当前状态。
    func clearedGrid() -> Grid {
        var next = grid
        for index in next.cells.indices where !givens.contains(index) {
            guard let cell = cell(at: index) else {
                continue
            }
            next[cell] = Grid.emptyCell
        }
        return next
    }
}
