extension GradingBoard {
    mutating func applyNakedSubset(size subsetSize: Int) -> Bool {
        for unit in layout.units {
            let unfixed = unit.filter { !fixed[$0] }
            guard unfixed.count > subsetSize else { continue }
            for subset in combinations(of: unfixed, size: subsetSize) {
                let union = subset.reduce(UInt16(0)) { $0 | candidates[$1] }
                guard union.nonzeroBitCount == subsetSize else { continue }
                if eliminateUnion(union, from: unfixed, subset: subset) { return true }
            }
        }
        return false
    }

    mutating func applyHiddenSubset(size subsetSize: Int) -> Bool {
        let allDigits = Array(1 ... 9)
        for unit in layout.units {
            let unfixed = unit.filter { !fixed[$0] }
            guard unfixed.count > subsetSize else { continue }
            for digitSubset in combinations(of: allDigits, size: subsetSize) {
                let digitMask = digitSubset.reduce(UInt16(0)) { $0 | (1 << UInt16($1 - 1)) }
                guard digitsAppear(in: unfixed, digits: digitSubset) else { continue }
                var targetCells = Set<Int>()
                for cell in unfixed where candidates[cell] & digitMask != 0 {
                    targetCells.insert(cell)
                }
                guard targetCells.count == subsetSize else { continue }
                if restrictCells(targetCells, to: digitMask) { return true }
            }
        }
        return false
    }

    private mutating func eliminateUnion(
        _ union: UInt16, from cells: [Int], subset: [Int]
    ) -> Bool {
        var changed = false
        for cell in cells where !subset.contains(cell) {
            let before = candidates[cell]
            let after = before & ~union
            guard after != before else { continue }
            changed = true
            for digit in values(mask: before & union) { clearCandidate(digit: digit, at: cell) }
        }
        return changed
    }

    private func digitsAppear(in cells: [Int], digits: [Int]) -> Bool {
        for digit in digits {
            let bit = UInt16(1 << (digit - 1))
            if !cells.contains(where: { candidates[$0] & bit != 0 }) { return false }
        }
        return true
    }

    private mutating func restrictCells(_ cells: Set<Int>, to mask: UInt16) -> Bool {
        var changed = false
        for cell in cells {
            let before = candidates[cell]
            let after = before & mask
            guard after != before else { continue }
            changed = true
            for digit in values(mask: before & ~mask) { clearCandidate(digit: digit, at: cell) }
        }
        return changed
    }
}
