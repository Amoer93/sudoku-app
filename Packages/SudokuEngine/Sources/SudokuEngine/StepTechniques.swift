/// 一步可以填入的格子和数字。
public struct StepPlacement: Codable, Equatable, Hashable, Sendable {
    public let cell: CellIndex
    public let digit: Int

    public init(cell: CellIndex, digit: Int) {
        self.cell = cell
        self.digit = digit
    }
}

/// 一步可以删掉的候选数。
public struct StepElimination: Codable, Equatable, Hashable, Sendable {
    public let cell: CellIndex
    public let digit: Int

    public init(cell: CellIndex, digit: Int) {
        self.cell = cell
        self.digit = digit
    }
}

/// 一种可以解释当前盘面下一步的技巧。
public struct StepTechnique: Codable, Equatable, Hashable, Sendable {
    /// 复用现有 Technique 枚举。宫排除与行列排除都用 .hiddenSingle，用 units 区分。
    public let technique: Technique
    /// 该看的区域（行/列/宫，0 起始）。复用现有 ConstraintUnit。
    public let units: [ConstraintUnit]
    /// 该技巧直接导致的填数（可空）。
    public let placements: [StepPlacement]
    /// 该技巧直接导致的删候选（可空）。
    public let eliminations: [StepElimination]

    /// 公开构造方法，方便 App 端自己组装或复制。
    public init(
        technique: Technique, units: [ConstraintUnit],
        placements: [StepPlacement], eliminations: [StepElimination]
    ) {
        self.technique = technique
        self.units = units
        self.placements = placements
        self.eliminations = eliminations
    }
}

/// 返回当前盘面上可以解释下一步的技巧，最多 3 项，按简单程度排序。
///
/// 只报告「可以用来走出这一步」的技巧，不推断玩家实际用了哪招。
/// 候选数只由当前盘面的行、列、宫排除得出，不使用玩家笔记。
/// 有冲突、已填满、某空格没有候选、或覆盖范围内没有任何可走步骤时，返回空数组。
/// 前置条件：`grid.size == rules.size`，否则触发 precondition。
public func stepTechniques(in grid: Grid, rules: Rules) -> [StepTechnique] {
    precondition(grid.size == rules.size, "grid.size must equal rules.size")

    guard conflicts(in: grid, rules: rules).isEmpty else { return [] }
    guard grid.cells.contains(Grid.emptyCell) else { return [] }

    let layout = BoardLayout(rules: rules)
    let masks = candidateMasks(for: grid, layout: layout)
    // 有空格没有候选数，说明盘面已经走不通。
    guard masks.allSatisfy({ $0 != 0 }) else { return [] }

    let detector = StepDetector(grid: grid, layout: layout, masks: masks)
    var found = detector.hiddenSingles()
    found += detector.nakedSingles()
    found += detector.intersections()
    found += detector.nakedPairs()
    found += detector.hiddenPairs()

    // 先按简单程度，再按区域、格子、数字排，保证结果固定。
    found.sort { $0.sortKey < $1.sortKey }
    return found.prefix(3).map(\.step)
}

// MARK: - 内部实现

/// 一个找到的技巧及其排序依据。
private struct FoundStep {
    let rank: Int
    let unitOrder: Int
    let cell: Int
    let digit: Int
    let step: StepTechnique

    var sortKey: (Int, Int, Int, Int) {
        (rank, unitOrder, cell, digit)
    }
}

/// 在当前候选数上查找各类技巧，不修改盘面。
private struct StepDetector {
    let grid: Grid
    let layout: BoardLayout
    let masks: [UInt16]

    // 排序名次（越小越简单）：0 宫排除，1 行列排除，2 唯一余数，
    // 3 宫区块，4 行列区块，5 显性数对，6 隐性数对。

    private var size: Int { grid.size }
    /// `layout.units` 的顺序是：所有行、所有列、所有宫。
    private var boxUnitStart: Int { 2 * size }

    // MARK: 单数技巧

    /// 隐性唯一：某区域里一个数字只剩一个可填格。
    func hiddenSingles() -> [FoundStep] {
        var result: [FoundStep] = []
        for unitIndex in layout.units.indices {
            for digit in 1 ... size {
                let cells = candidateCells(in: layout.units[unitIndex], digit: digit)
                guard cells.count == 1 else { continue }
                result.append(makeStep(
                    rank: unitIndex >= boxUnitStart ? 0 : 1,
                    unitIndex: unitIndex, cell: cells[0], digit: digit,
                    technique: .hiddenSingle, units: [constraintUnit(unitIndex)],
                    placements: [placement(cells[0], digit)]
                ))
            }
        }
        return result
    }

    /// 唯一余数：空格只剩一个候选数。
    func nakedSingles() -> [FoundStep] {
        var result: [FoundStep] = []
        for cell in grid.cells.indices where grid.cells[cell] == Grid.emptyCell {
            guard masks[cell].nonzeroBitCount == 1 else { continue }
            let digit = masks[cell].trailingZeroBitCount + 1
            var units = [constraintUnit(cell / size), constraintUnit(size + cell % size)]
            // 5×5 没有宫，切片为空，自然跳过。
            if let boxUnit = layout.units[boxUnitStart...].firstIndex(where: { $0.contains(cell) }) {
                units.append(constraintUnit(boxUnit))
            }
            result.append(FoundStep(
                rank: 2, unitOrder: 0, cell: cell, digit: digit,
                step: StepTechnique(
                    technique: .nakedSingle, units: units,
                    placements: [placement(cell, digit)], eliminations: []
                )
            ))
        }
        return result
    }

    // MARK: 区块技巧

    /// 宫区块（pointing）与行列区块（claiming）。
    func intersections() -> [FoundStep] {
        var result: [FoundStep] = []
        for digit in 1 ... size {
            for box in boxUnitStart ..< layout.units.count {
                for line in 0 ..< boxUnitStart {
                    result += intersectionStep(source: box, target: line, digit: digit, rank: 3)
                    result += intersectionStep(source: line, target: box, digit: digit, rank: 4)
                }
            }
        }
        return result
    }

    /// 来源区域里某数字的候选全落在目标区域内时，可从目标区域其余格删掉它。
    private func intersectionStep(source: Int, target: Int, digit: Int, rank: Int) -> [FoundStep] {
        let sourceCells = candidateCells(in: layout.units[source], digit: digit)
        // 只有一个候选格时是隐性唯一，不算区块。
        guard sourceCells.count >= 2 else { return [] }
        let targetUnit = layout.units[target]
        guard sourceCells.allSatisfy({ targetUnit.contains($0) }) else { return [] }

        var removed: [StepElimination] = []
        for cell in candidateCells(in: targetUnit, digit: digit) where !sourceCells.contains(cell) {
            removed.append(elimination(cell, digit))
        }
        guard !removed.isEmpty else { return [] }

        let technique: Technique = (rank == 3) ? .pointing : .boxLineReduction
        return [makeStep(
            rank: rank, unitIndex: source, cell: sourceCells[0], digit: digit,
            technique: technique, units: [constraintUnit(source), constraintUnit(target)],
            eliminations: removed
        )]
    }

    // MARK: 数对技巧

    /// 显性数对：区域内两格候选完全相同且只有两个数。
    func nakedPairs() -> [FoundStep] {
        var result: [FoundStep] = []
        for unitIndex in layout.units.indices {
            let unit = layout.units[unitIndex]
            var pairCells: [Int] = []
            for cell in unit where grid.cells[cell] == Grid.emptyCell && masks[cell].nonzeroBitCount == 2 {
                pairCells.append(cell)
            }
            for pair in combinations(of: pairCells, size: 2) where masks[pair[0]] == masks[pair[1]] {
                let pairMask = masks[pair[0]]
                var removed: [StepElimination] = []
                for cell in unit where grid.cells[cell] == Grid.emptyCell && !pair.contains(cell) {
                    removed += eliminations(of: masks[cell] & pairMask, at: cell)
                }
                guard !removed.isEmpty else { continue }
                result.append(makeStep(
                    rank: 5, unitIndex: unitIndex, cell: pair[0],
                    digit: pairMask.trailingZeroBitCount + 1,
                    technique: .nakedPair, units: [constraintUnit(unitIndex)], eliminations: removed
                ))
            }
        }
        return result
    }

    /// 隐性数对：区域内两个数字只出现在同样的两格里。
    func hiddenPairs() -> [FoundStep] {
        var result: [FoundStep] = []
        for unitIndex in layout.units.indices {
            let unit = layout.units[unitIndex]
            var digitsWithTwoCells: [Int] = []
            for digit in 1 ... size where candidateCells(in: unit, digit: digit).count == 2 {
                digitsWithTwoCells.append(digit)
            }
            for pair in combinations(of: digitsWithTwoCells, size: 2) {
                let cells = candidateCells(in: unit, digit: pair[0])
                guard cells == candidateCells(in: unit, digit: pair[1]) else { continue }
                let pairMask = (UInt16(1) << UInt16(pair[0] - 1)) | (UInt16(1) << UInt16(pair[1] - 1))
                var removed: [StepElimination] = []
                for cell in cells {
                    removed += eliminations(of: masks[cell] & ~pairMask, at: cell)
                }
                guard !removed.isEmpty else { continue }
                result.append(makeStep(
                    rank: 6, unitIndex: unitIndex, cell: cells[0], digit: pair[0],
                    technique: .hiddenPair, units: [constraintUnit(unitIndex)], eliminations: removed
                ))
            }
        }
        return result
    }

    // MARK: 小工具

    /// 区域内仍有某数字候选的空格，按下标从小到大。
    private func candidateCells(in unit: [Int], digit: Int) -> [Int] {
        let bit = UInt16(1) << UInt16(digit - 1)
        var cells: [Int] = []
        for cell in unit where grid.cells[cell] == Grid.emptyCell && masks[cell] & bit != 0 {
            cells.append(cell)
        }
        return cells
    }

    /// 把掩码里的每个数字变成该格的一个删候选。
    private func eliminations(of mask: UInt16, at cell: Int) -> [StepElimination] {
        var result: [StepElimination] = []
        for digit in 1 ... size where mask & (UInt16(1) << UInt16(digit - 1)) != 0 {
            result.append(elimination(cell, digit))
        }
        return result
    }

    /// 把 `layout.units` 下标转成 `ConstraintUnit`。
    private func constraintUnit(_ unitIndex: Int) -> ConstraintUnit {
        let index = unitIndex % size
        switch unitIndex / size {
        case 0: return .row(index)
        case 1: return .column(index)
        default: return .box(index)
        }
    }

    private func placement(_ cell: Int, _ digit: Int) -> StepPlacement {
        StepPlacement(cell: CellIndex(linearIndex: cell, size: size), digit: digit)
    }
    private func elimination(_ cell: Int, _ digit: Int) -> StepElimination {
        StepElimination(cell: CellIndex(linearIndex: cell, size: size), digit: digit)
    }

    /// 组装一项结果；同名次时按「宫、行、列」再按编号排。
    private func makeStep(
        rank: Int, unitIndex: Int, cell: Int, digit: Int,
        technique: Technique, units: [ConstraintUnit],
        placements: [StepPlacement] = [], eliminations: [StepElimination] = []
    ) -> FoundStep {
        let kind = unitIndex / size
        let kindOrder = (kind == 2) ? 0 : kind + 1
        return FoundStep(
            rank: rank, unitOrder: kindOrder * 100 + unitIndex % size, cell: cell, digit: digit,
            step: StepTechnique(
                technique: technique, units: units, placements: placements, eliminations: eliminations
            )
        )
    }
}
