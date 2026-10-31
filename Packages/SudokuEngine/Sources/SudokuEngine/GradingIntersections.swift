extension GradingBoard {
    mutating func applyPointing() -> Bool {
        for box in boxUnits {
            for digit in 1 ... 9 {
                let cells = box.filter { !fixed[$0] && candidates[$0] & (1 << UInt16(digit - 1)) != 0 }
                guard cells.count > 1 else { continue }
                let rows = Set(cells.map { $0 / 9 })
                let cols = Set(cells.map { $0 % 9 })
                if rows.count == 1, let row = rows.first {
                    if eliminate(digit: digit, from: rowUnits[row], except: box) { return true }
                }
                if cols.count == 1, let col = cols.first {
                    if eliminate(digit: digit, from: columnUnits[col], except: box) { return true }
                }
            }
        }
        return false
    }

    mutating func applyBoxLineReduction() -> Bool {
        for unit in rowUnits + columnUnits {
            for digit in 1 ... 9 {
                let cells = unit.filter { !fixed[$0] && candidates[$0] & (1 << UInt16(digit - 1)) != 0 }
                guard cells.count > 1 else { continue }
                let boxes = Set(cells.map(boxIndex))
                if boxes.count == 1, let boxIdx = boxes.first {
                    if eliminate(digit: digit, from: boxUnits[boxIdx], except: unit) { return true }
                }
            }
        }
        return false
    }

    private mutating func eliminate(digit: Int, from unit: [Int], except excluded: [Int]) -> Bool {
        var changed = false
        for cell in unit where !excluded.contains(cell) && !fixed[cell] {
            if candidates[cell] & (1 << UInt16(digit - 1)) != 0 {
                clearCandidate(digit: digit, at: cell)
                changed = true
            }
        }
        return changed
    }
}
