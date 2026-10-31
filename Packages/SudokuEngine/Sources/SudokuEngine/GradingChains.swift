extension GradingBoard {
    mutating func applyXYWing() -> Bool {
        for pivot in 0 ..< 81 where !fixed[pivot] && candidates[pivot].nonzeroBitCount == 2 {
            let pivotMask = candidates[pivot]
            let peers = layout.peers[pivot]
            for idx in 0 ..< peers.count {
                let pincer1 = peers[idx]
                guard !fixed[pincer1] && candidates[pincer1].nonzeroBitCount == 2 else { continue }
                let mask1 = candidates[pincer1]
                guard (pivotMask & mask1).nonzeroBitCount == 1 else { continue }
                let common1 = pivotMask & mask1
                for jdx in (idx + 1) ..< peers.count {
                    let pincer2 = peers[jdx]
                    guard !fixed[pincer2] && candidates[pincer2].nonzeroBitCount == 2 else { continue }
                    let mask2 = candidates[pincer2]
                    guard pivotMask & mask2 == pivotMask ^ common1 else { continue }
                    guard (mask1 & mask2).nonzeroBitCount == 1 else { continue }
                    let digit = (mask1 & mask2).trailingZeroBitCount + 1
                    if eliminateZFromXYWing(pincer1: pincer1, pincer2: pincer2, digit: digit) { return true }
                }
            }
        }
        return false
    }

    private mutating func eliminateZFromXYWing(pincer1: Int, pincer2: Int, digit: Int) -> Bool {
        var changed = false
        for cell in 0 ..< 81 where !fixed[cell] && cell != pincer1 && cell != pincer2 {
            if layout.peers[pincer1].contains(cell) && layout.peers[pincer2].contains(cell) {
                if candidates[cell] & (1 << UInt16(digit - 1)) != 0 {
                    clearCandidate(digit: digit, at: cell)
                    changed = true
                }
            }
        }
        return changed
    }

    mutating func applySimpleColoring() -> Bool {
        for digit in 1 ... 9 {
            let graph = buildConjugateGraph(digit: digit)
            var visited = Set<Int>()
            // 按下标排序遍历，保证结果与字典哈希顺序无关
            for start in graph.keys.sorted() {
                guard visited.insert(start).inserted else { continue }
                var component = [start]
                var colors: [Int: Bool] = [start: true]
                var queue = [start]
                while let node = queue.popLast() {
                    for neighbor in graph[node, default: []].sorted() {
                        guard visited.insert(neighbor).inserted else { continue }
                        colors[neighbor] = !(colors[node] ?? true)
                        component.append(neighbor)
                        queue.append(neighbor)
                    }
                }
                if eliminateByChain(digit: digit, component: component, colors: colors) { return true }
            }
        }
        return false
    }

    private func buildConjugateGraph(digit: Int) -> [Int: Set<Int>] {
        let bit = UInt16(1 << (digit - 1))
        var graph: [Int: Set<Int>] = [:]
        for unit in layout.units {
            let cells = unit.filter { !fixed[$0] && candidates[$0] & bit != 0 }
            guard cells.count == 2 else { continue }
            graph[cells[0], default: []].insert(cells[1])
            graph[cells[1], default: []].insert(cells[0])
        }
        return graph
    }

    private mutating func eliminateByChain(
        digit: Int, component: [Int], colors: [Int: Bool]
    ) -> Bool {
        let bit = UInt16(1 << (digit - 1))
        let trueCells = component.filter { colors[$0] == true }
        let falseCells = component.filter { colors[$0] == false }
        for group in [trueCells, falseCells] {
            if hasPeerPair(in: group) {
                for cell in group where !fixed[cell] && candidates[cell] & bit != 0 {
                    clearCandidate(digit: digit, at: cell)
                }
                return true
            }
        }
        let colored = Set(component)
        for cell in 0 ..< 81 where !fixed[cell] && candidates[cell] & bit != 0 && !colored.contains(cell) {
            var seesTrue = false
            var seesFalse = false
            for peer in layout.peers[cell] {
                if trueCells.contains(peer) { seesTrue = true }
                if falseCells.contains(peer) { seesFalse = true }
            }
            if seesTrue && seesFalse {
                clearCandidate(digit: digit, at: cell)
                return true
            }
        }
        return false
    }

    private func hasPeerPair(in cells: [Int]) -> Bool {
        for idx in 0 ..< cells.count {
            for jdx in (idx + 1) ..< cells.count {
                if layout.peers[cells[idx]].contains(cells[jdx]) { return true }
            }
        }
        return false
    }
}
