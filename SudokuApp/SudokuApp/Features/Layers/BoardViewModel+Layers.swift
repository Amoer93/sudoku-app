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

/// 假设层的只读部分。拆到单独文件是为了让 BoardViewModel.swift 满足 SwiftLint 的长度限制。
/// 所有会写 grid、notice、层和撤销栈的方法（开层、回滚等）都在 BoardViewModel.swift 里。
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

    /// 当前高亮的格子是否是「建议假设格」（而不是确定格）。
    var isHintAnAssumption: Bool {
        guard hintedIndex != nil, case .assumption = notice else {
            return false
        }
        return true
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
}
