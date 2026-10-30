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

    /// 能否开新层：最上层还没填过数字时不允许，避免叠出一层空的假设。
    var canStartLayer: Bool {
        guard !isSolving else {
            return false
        }
        guard let top = layers.last else {
            return true
        }
        return grid != top.snapshot.grid || cellDepths != top.snapshot.depths
    }

    /// 开一层新假设，可以嵌套。
    func startLayer() {
        guard canStartLayer else {
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

    /// 当前高亮的格子是否是「建议假设格」（而不是确定格）。
    var isHintAnAssumption: Bool {
        guard hintedIndex != nil, case .assumption = notice else {
            return false
        }
        return true
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
