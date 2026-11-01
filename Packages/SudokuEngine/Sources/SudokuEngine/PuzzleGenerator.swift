/// 可重复的伪随机数生成器（SplitMix64）。同一个种子永远产生同一串数字。
public struct PuzzleRandomGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// 用种子创建生成器。
    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_9B5D
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// 9×9 数独出题器。只用于生成内置题库，结果完全由随机数生成器决定。
public enum PuzzleGenerator {
    /// 随机生成一个完整、合法的 9×9 解盘。
    public static func makeSolution<G: RandomNumberGenerator>(using generator: inout G) -> Grid {
        var state = FillState()
        let filled = fill(position: 0, state: &state, using: &generator)
        precondition(filled, "a full grid always exists")
        return makeGrid(from: state.cells)
    }

    /// 从解盘挖空出题，保证唯一解。
    ///
    /// 按随机顺序逐格尝试挖掉；挖掉后若出现多解就放回。
    /// 给定数降到 `targetGivens` 时停止；传 0 表示一直挖到不能再挖（极小题）。
    public static func makePuzzle<G: RandomNumberGenerator>(
        targetGivens: Int,
        using generator: inout G
    ) -> Grid {
        var puzzle = makeSolution(using: &generator)
        var givenCount = 81
        let order = Array(0 ..< 81).shuffled(using: &generator)
        for position in order where givenCount > targetGivens {
            let cell = CellIndex(linearIndex: position, size: 9)
            let removedValue = puzzle[cell]
            puzzle[cell] = Grid.emptyCell
            if solutionCount(puzzle, rules: .nineByNine, limit: 2) == 1 {
                givenCount -= 1
            } else {
                // 挖掉后不唯一，必须放回，否则题目作废
                puzzle[cell] = removedValue
            }
        }
        return puzzle
    }

    /// 带随机顺序的回溯填盘。成功返回 true。
    private static func fill<G: RandomNumberGenerator>(
        position: Int,
        state: inout FillState,
        using generator: inout G
    ) -> Bool {
        if position == 81 { return true }
        let row = position / 9
        let column = position % 9
        let box = (row / 3) * 3 + column / 3
        let used = state.rows[row] | state.columns[column] | state.boxes[box]
        var digits: [Int] = []
        for digit in 1 ... 9 where used & (1 << digit) == 0 {
            digits.append(digit)
        }
        digits.shuffle(using: &generator)
        for digit in digits {
            state.place(digit, row: row, column: column, box: box)
            if fill(position: position + 1, state: &state, using: &generator) { return true }
            state.remove(digit, row: row, column: column, box: box)
        }
        return false
    }

    /// 把生成器产出的格子数组转成 Grid；失败说明程序有 bug。
    private static func makeGrid(from cells: [Int]) -> Grid {
        guard let grid = try? Grid(size: 9, cells: cells) else {
            preconditionFailure("generator produced an invalid grid")
        }
        return grid
    }
}

/// 回溯填盘的状态：格子内容，以及行、列、宫已用数字的位掩码。
private struct FillState {
    var cells = [Int](repeating: Grid.emptyCell, count: 81)
    var rows = [Int](repeating: 0, count: 9)
    var columns = [Int](repeating: 0, count: 9)
    var boxes = [Int](repeating: 0, count: 9)

    mutating func place(_ digit: Int, row: Int, column: Int, box: Int) {
        cells[row * 9 + column] = digit
        rows[row] |= 1 << digit
        columns[column] |= 1 << digit
        boxes[box] |= 1 << digit
    }

    mutating func remove(_ digit: Int, row: Int, column: Int, box: Int) {
        cells[row * 9 + column] = Grid.emptyCell
        rows[row] &= ~(1 << digit)
        columns[column] &= ~(1 << digit)
        boxes[box] &= ~(1 << digit)
    }
}
