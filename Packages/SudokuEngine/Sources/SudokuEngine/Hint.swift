/// 一个确定性格子提示。
public struct Hint: Codable, Equatable, Hashable, Sendable {
    /// 应填入的格子。
    public let target: CellIndex

    /// 应填入的数字（`1...rules.size`）。
    public let value: Int

    /// 使用的技巧与推理依据。
    public let technique: HintTechnique
}

/// 提示使用的技巧及推理依据单元。
public enum HintTechnique: Codable, Equatable, Hashable, Sendable {
    /// 裸单：目标格的候选数被所在行、列、宫的已知数字排除到只剩一个。
    /// `reasonUnits` 为目标格所在的行、列、宫（5×5 时无宫）。
    case nakedSingle(reasonUnits: [ConstraintUnit])

    /// 隐性唯一：在 `unit` 这个单元里，`value` 只能放在 `target` 这一格。
    case hiddenSingle(unit: ConstraintUnit)
}

/// 一个约束单元：行、列或宫，均从 0 开始编号。
public enum ConstraintUnit: Codable, Equatable, Hashable, Sendable {
    case row(Int)
    case column(Int)
    case box(Int)
}

/// 寻找当前盘面上下一个确定性格子提示。
///
/// 只识别裸单（naked single）与隐性唯一（hidden single）两种技巧。
/// 找到确定格时返回 `Hint`；当前盘面不存在确定格时返回 `nil`。
///
/// 若盘面已有冲突，或已经填满，也返回 `nil`。
///
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。
/// 复杂度目标：9×9 在 iPhone 上小于 50ms。
public func hint(in grid: Grid, rules: Rules) -> Hint? {
    precondition(grid.size == rules.size, "grid.size must equal rules.size")

    guard conflicts(in: grid, rules: rules).isEmpty else { return nil }
    guard grid.cells.contains(Grid.emptyCell) else { return nil }

    let layout = BoardLayout(rules: rules)
    let masks = candidateMasks(for: grid, layout: layout)

    // 任一空格无候选，说明盘面无解或隐含冲突。
    guard masks.allSatisfy({ $0 != 0 }) else { return nil }

    // 1) 先找裸单，按行优先顺序。
    for cell in 0 ..< grid.cells.count where grid.cells[cell] == Grid.emptyCell {
        let mask = masks[cell]
        if mask.nonzeroBitCount == 1 {
            let value = mask.trailingZeroBitCount + 1
            let target = CellIndex(linearIndex: cell, size: grid.size)
            return Hint(
                target: target,
                value: value,
                technique: .nakedSingle(reasonUnits: containingUnits(for: target, rules: rules))
            )
        }
    }

    // 2) 再找隐性唯一，按行、列、宫顺序。
    for unit in layout.units {
        var placedMask: UInt16 = 0
        for cell in unit where grid.cells[cell] != Grid.emptyCell {
            placedMask |= 1 << UInt16(grid.cells[cell] - 1)
        }

        for value in 1 ... rules.size {
            let bit: UInt16 = 1 << UInt16(value - 1)
            guard placedMask & bit == 0 else { continue }

            var foundCell: Int?
            for cell in unit where grid.cells[cell] == Grid.emptyCell {
                guard masks[cell] & bit != 0 else { continue }
                if foundCell == nil {
                    foundCell = cell
                } else {
                    foundCell = nil
                    break
                }
            }

            if let cell = foundCell {
                let target = CellIndex(linearIndex: cell, size: grid.size)
                return Hint(
                    target: target,
                    value: value,
                    technique: .hiddenSingle(unit: constraintUnit(for: unit, rules: rules))
                )
            }
        }
    }

    return nil
}

// MARK: - 内部辅助

/// 计算每个格子的候选数位掩码。
///
/// 已填格为单一位掩码；空格为同行、同列、同宫已填数字排除后的掩码。
private func candidateMasks(for grid: Grid, layout: BoardLayout) -> [UInt16] {
    let allValues = UInt16((1 << grid.size) - 1)
    var masks = Array(repeating: allValues, count: grid.cells.count)

    for (cell, value) in grid.cells.enumerated() where value != Grid.emptyCell {
        masks[cell] = 1 << UInt16(value - 1)
    }

    for cell in 0 ..< grid.cells.count where grid.cells[cell] == Grid.emptyCell {
        var mask = allValues
        for peer in layout.peers[cell] {
            let peerValue = grid.cells[peer]
            if peerValue != Grid.emptyCell {
                mask &= ~(1 << UInt16(peerValue - 1))
            }
        }
        masks[cell] = mask
    }

    return masks
}

/// 返回目标格所在的行、列、宫单元列表（5×5 时只有行和列）。
private func containingUnits(for target: CellIndex, rules: Rules) -> [ConstraintUnit] {
    var units: [ConstraintUnit] = [
        .row(target.row),
        .column(target.column),
    ]

    if rules.hasBoxes, let boxRows = rules.boxRows, let boxCols = rules.boxCols {
        let boxIndex = (target.row / boxRows) * (rules.size / boxCols) + (target.column / boxCols)
        units.append(.box(boxIndex))
    }

    return units
}

/// 把一个 `BoardLayout` 中的单元映射为 `ConstraintUnit`。
private func constraintUnit(for unit: [Int], rules: Rules) -> ConstraintUnit {
    let first = unit[0]

    // 行：连续 size 个下标，且起始下标是 size 的倍数。
    if unit.count == rules.size,
       unit.last! - first == rules.size - 1,
       first % rules.size == 0 {
        return .row(first / rules.size)
    }

    // 列：所有下标模 size 相同。
    let column = first % rules.size
    if unit.allSatisfy({ $0 % rules.size == column }) {
        return .column(column)
    }

    // 宫：剩余情况。
    let topRow = first / rules.size
    let leftColumn = first % rules.size
    if let boxRows = rules.boxRows, let boxCols = rules.boxCols {
        let boxIndex = (topRow / boxRows) * (rules.size / boxCols) + (leftColumn / boxCols)
        return .box(boxIndex)
    }

    fatalError("unexpected unit: \(unit)")
}
