extension GradingBoard {
    mutating func applyXWing() -> Bool {
        applyFish(size: 2)
    }

    mutating func applySwordfish() -> Bool {
        applyFish(size: 3)
    }

    private mutating func applyFish(size: Int) -> Bool {
        for digit in 1 ... 9 {
            if eliminateFish(digit: digit, size: size, primary: rowUnits, secondary: columnUnits,
                             primaryIndex: { $0 / 9 }, secondaryIndex: { $0 % 9 }) { return true }
            if eliminateFish(digit: digit, size: size, primary: columnUnits, secondary: rowUnits,
                             primaryIndex: { $0 % 9 }, secondaryIndex: { $0 / 9 }) { return true }
        }
        return false
    }

    private mutating func eliminateFish(
        digit: Int, size: Int, primary: [[Int]], secondary: [[Int]],
        primaryIndex: (Int) -> Int, secondaryIndex: (Int) -> Int
    ) -> Bool {
        let bit = UInt16(1 << (digit - 1))
        let valid = primary.enumerated().compactMap { (idx, unit) -> (idx: Int, cells: [Int])? in
            let cells = unit.filter { !fixed[$0] && candidates[$0] & bit != 0 }
            guard cells.count >= 2 && cells.count <= size else { return nil }
            return (idx, cells)
        }
        guard valid.count >= size else { return false }
        for combo in combinations(of: Array(0 ..< valid.count), size: size) {
            let selected = combo.map { valid[$0] }
            let secondarySet = Set(selected.flatMap { $0.cells.map(secondaryIndex) }).sorted()
            guard secondarySet.count == size else { continue }
            var changed = false
            for secIdx in secondarySet {
                for cell in secondary[secIdx] where !fixed[cell] && candidates[cell] & bit != 0 {
                    guard !selected.contains(where: { $0.idx == primaryIndex(cell) }) else { continue }
                    clearCandidate(digit: digit, at: cell)
                    changed = true
                }
            }
            if changed { return true }
        }
        return false
    }
}
