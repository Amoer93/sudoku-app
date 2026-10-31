/// 候选数模型，用于人工技巧评分。
struct GradingBoard {
    var candidates: [UInt16]
    var fixed: [Bool]
    let layout: BoardLayout
    private let solution: Grid
    let rowUnits: [[Int]]
    let columnUnits: [[Int]]
    let boxUnits: [[Int]]

    init?(grid: Grid, solution: Grid) {
        layout = BoardLayout(rules: .nineByNine)
        self.solution = solution
        let allValues = UInt16((1 << 9) - 1)
        candidates = Array(repeating: allValues, count: 81)
        fixed = Array(repeating: false, count: 81)
        for (cell, value) in grid.cells.enumerated() where value != Grid.emptyCell {
            guard value == solution.cells[cell] else { return nil }
            candidates[cell] = 1 << UInt16(value - 1)
            fixed[cell] = true
        }
        rowUnits = Array(layout.units.prefix(9))
        columnUnits = Array(layout.units[9 ..< 18])
        boxUnits = Array(layout.units.suffix(9))
        for (cell, value) in grid.cells.enumerated() where value != Grid.emptyCell {
            for peer in layout.peers[cell] where !fixed[peer] {
                candidates[peer] &= ~(1 << UInt16(value - 1))
            }
        }
    }

    var isSolved: Bool { fixed.allSatisfy { $0 } }

    mutating func applyNakedSingle() -> Bool {
        for cell in 0 ..< 81 where !fixed[cell] && candidates[cell].nonzeroBitCount == 1 {
            place(digit: candidates[cell].trailingZeroBitCount + 1, at: cell)
            return true
        }
        return false
    }

    mutating func applyHiddenSingle(boxesOnly: Bool) -> Bool {
        let units = boxesOnly ? boxUnits : rowUnits + columnUnits
        for unit in units {
            let placedMask = placedMask(in: unit)
            for digit in 1 ... 9 {
                let bit = UInt16(1 << (digit - 1))
                guard placedMask & bit == 0 else { continue }
                var target: Int?
                for cell in unit where !fixed[cell] && candidates[cell] & bit != 0 {
                    if target == nil { target = cell } else { target = nil; break }
                }
                if let cell = target {
                    place(digit: digit, at: cell)
                    return true
                }
            }
        }
        return false
    }

    mutating func applyTrialAndError() -> Bool {
        var bestCell: Int?
        var bestCount = Int.max
        for cell in 0 ..< 81 where !fixed[cell] {
            let count = candidates[cell].nonzeroBitCount
            if count < bestCount { bestCell = cell; bestCount = count }
        }
        guard let cell = bestCell else { return false }
        place(digit: solution.cells[cell], at: cell)
        return true
    }

    func values(at cell: Int) -> [Int] {
        values(mask: candidates[cell])
    }

    mutating func clearCandidate(digit: Int, at cell: Int) {
        let bit = UInt16(1 << (digit - 1))
        guard candidates[cell] & bit != 0 else { return }
        #if DEBUG
            assert(solution.cells[cell] != digit, "eliminated unique solution digit")
        #endif
        candidates[cell] &= ~bit
    }

    private mutating func place(digit: Int, at cell: Int) {
        #if DEBUG
            assert(solution.cells[cell] == digit, "placed digit must match unique solution")
        #endif
        candidates[cell] = UInt16(1 << (digit - 1))
        fixed[cell] = true
        for peer in layout.peers[cell] where !fixed[peer] {
            _ = eliminate(digit: digit, from: peer)
        }
    }

    @discardableResult
    private mutating func eliminate(digit: Int, from cell: Int) -> Bool {
        let bit = UInt16(1 << (digit - 1))
        guard candidates[cell] & bit != 0 else { return false }
        #if DEBUG
            assert(solution.cells[cell] != digit, "eliminated unique solution digit")
        #endif
        candidates[cell] &= ~bit
        return true
    }

    private func placedMask(in unit: [Int]) -> UInt16 {
        var mask: UInt16 = 0
        for cell in unit where fixed[cell] {
            mask |= candidates[cell]
        }
        return mask
    }

    func values(mask: UInt16) -> [Int] {
        var result: [Int] = []
        var remaining = mask
        while remaining != 0 {
            result.append(remaining.trailingZeroBitCount + 1)
            remaining &= remaining - 1
        }
        return result
    }
}

func combinations<T>(of array: [T], size: Int) -> [[T]] {
    guard size > 0 else { return [[]] }
    guard array.count >= size else { return [] }
    if size == 1 { return array.map { [$0] } }
    var result: [[T]] = []
    for idx in 0 ... (array.count - size) {
        for combo in combinations(of: Array(array[(idx + 1)...]), size: size - 1) {
            result.append([array[idx]] + combo)
        }
    }
    return result
}

func boxIndex(of cell: Int) -> Int {
    (cell / 27) * 3 + (cell % 9) / 3
}
