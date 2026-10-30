/// 撤销栈里的一条记录：盘面加上每格所属的假设层。
/// 存储属性要放在 BoardViewModel 里，所以这里的类型不能再用 private。
struct BoardSnapshot {
    let grid: Grid
    let depths: [Int]
}

/// 一层假设：开始前的快照，以及开始时撤销栈的长度（回滚时据此丢掉本层记录）。
struct AssumptionLayer {
    let snapshot: BoardSnapshot
    let undoCount: Int
}

/// 假设层相关的逻辑。拆到单独文件是为了让 BoardViewModel.swift 满足 SwiftLint 的长度限制。
/// 扩展在另一个文件里，看不到 private 成员，所以主文件里被用到的属性只放宽到 internal。
extension BoardViewModel {
    /// 当前假设层数，0 表示没有开启假设。
    var currentLayerDepth: Int {
        layers.count
    }

    var canRollbackLayer: Bool {
        !layers.isEmpty && !isSolving
    }

    /// 某格数字所属的层，越界返回 0。
    func layerDepth(at index: Int) -> Int {
        guard cellDepths.indices.contains(index) else {
            return 0
        }
        return cellDepths[index]
    }

    /// 开一层新假设，可以嵌套。
    func startLayer() {
        guard !isSolving else {
            return
        }
        layers.append(AssumptionLayer(snapshot: snapshot(), undoCount: undoStack.count))
    }

    /// 撤回最上面一层：本层改过的格子全部回到开层前的值，本层的撤销记录一并丢掉。
    func rollbackLayer() {
        guard !isSolving, let layer = layers.popLast() else {
            return
        }
        grid = layer.snapshot.grid
        cellDepths = layer.snapshot.depths
        if undoStack.count > layer.undoCount {
            undoStack.removeSubrange(layer.undoCount...)
        }
        // 重做栈里的盘面可能含本层内容，留着会把已撤回的数字带回来
        redoStack.removeAll()
        refreshConflicts()
        notice = .idle
        scheduleSolutionCount()
    }

    func snapshot() -> BoardSnapshot {
        BoardSnapshot(grid: grid, depths: cellDepths)
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
}
