// 小棋盘（4×4、5×5）的评分、分档和指纹。只靠"唯一数"一步步推，不试数。

/// 小棋盘评分结果。
struct SmallBoardRating: Equatable {
    let seRating: Double
    let score: Int
    /// 前半程里，每一步"能直接填的格子数"的最小值；越大说明开局越宽松。
    let minEarlyFillable: Int
}

/// 分档表：某个边长、某一档要求的给定数范围和开局宽松度（`minEarlyFillable` 的下限）。
private let smallTierRules: [(size: Int, tier: Difficulty, givens: ClosedRange<Int>, minEarlyFillable: Int)] = [
    (4, .easy, 8 ... 10, 4), (4, .hard, 4 ... 6, 0), (5, .easy, 12 ... 14, 4), (5, .hard, 7 ... 9, 0)
]

/// 一步可用的填法。`rating` 是 SE 值乘 10：宫内唯一 12，行列唯一 15，唯余 23。
private typealias SingleMove = (rating: Int, cell: Int, digit: Int)

/// 只用唯一数解题并评分；卡住（需要更难的技巧或题目有矛盾）时返回 nil。
func rateSmallBoard(_ grid: Grid, rules: Rules) -> SmallBoardRating? {
    let layout = BoardLayout(rules: rules)
    var cells = grid.cells
    let blanks = cells.filter { $0 == Grid.emptyCell }.count
    let earlySteps = max(1, blanks / 2)
    var hardest = 0
    var score = 0
    var minEarlyFillable = blanks
    for step in 0 ..< blanks {
        let moves = singleMoves(cells: cells, layout: layout)
        // 先挑最简单的技巧，再挑格子编号小的、数字小的，保证结果固定
        guard let best = moves.min(by: { $0 < $1 }) else { return nil }
        if step < earlySteps {
            minEarlyFillable = min(minEarlyFillable, Set(moves.map(\.cell)).count)
        }
        cells[best.cell] = best.digit
        hardest = max(hardest, best.rating)
        score += best.rating
    }
    return SmallBoardRating(seRating: Double(hardest) / 10, score: score, minEarlyFillable: minEarlyFillable)
}

/// 给小棋盘题分档（只有简单和困难）。不唯一解、要试数、或给定数不在范围内都返回 nil。
func gradeSmallBoard(_ grid: Grid, rules: Rules) -> (difficulty: Difficulty, rating: SmallBoardRating)? {
    guard solutionCount(grid, rules: rules, limit: 2) == 1,
          let rating = rateSmallBoard(grid, rules: rules) else { return nil }
    let givens = grid.cells.filter { $0 != Grid.emptyCell }.count
    for rule in smallTierRules where rule.size == rules.size && rule.givens.contains(givens) {
        if rating.minEarlyFillable >= rule.minEarlyFillable { return (rule.tier, rating) }
    }
    return nil
}

/// 找出当前局面所有的唯一数填法（同一格可能出现多次）。
private func singleMoves(cells: [Int], layout: BoardLayout) -> [SingleMove] {
    var candidates = [[Int]](repeating: [], count: cells.count)
    var moves: [SingleMove] = []
    for cell in cells.indices where cells[cell] == Grid.emptyCell {
        let used = Set(layout.peers[cell].map { cells[$0] })
        candidates[cell] = (1 ... layout.size).filter { !used.contains($0) }
        if candidates[cell].count == 1 {
            moves.append((23, cell, candidates[cell][0]))
        }
    }
    for (unitIndex, unit) in layout.units.enumerated() {
        // 单元顺序是行、列、宫；宫里的唯一数最容易看出来
        let rating = unitIndex >= 2 * layout.size ? 12 : 15
        for digit in 1 ... layout.size {
            let places = unit.filter { candidates[$0].contains(digit) }
            if places.count == 1 {
                moves.append((rating, places[0], digit))
            }
        }
    }
    return moves
}

/// 4×4 里保持 2×2 宫结构的行（列）排列：带内互换、两条带互换。
private let bandPermutations: [[Int]] = [
    [0, 1, 2, 3], [1, 0, 2, 3], [0, 1, 3, 2], [1, 0, 3, 2],
    [2, 3, 0, 1], [3, 2, 0, 1], [2, 3, 1, 0], [3, 2, 1, 0]
]

/// `0 ..< count` 的全部排列。
private func allPermutations(of count: Int) -> [[Int]] {
    if count == 0 { return [[]] }
    var result: [[Int]] = []
    for shorter in allPermutations(of: count - 1) {
        for position in 0 ... shorter.count {
            var longer = shorter
            longer.insert(count - 1, at: position)
            result.append(longer)
        }
    }
    return result
}

/// 小棋盘指纹：转置、行列排列、数字重标后等价的题共享同一个指纹。
///
/// 做法是穷举所有摆法，取字典序最小的一串。前缀 `s4-` / `s5-` 保证不会和 9×9 指纹撞车。
func smallFingerprint(_ grid: Grid, rules: Rules) -> PuzzleFingerprint {
    precondition(rules.size == grid.size && rules.size < 9, "only 4x4 and 5x5 boards")
    let size = rules.size
    let linePermutations = rules.hasBoxes ? bandPermutations : allPermutations(of: size)
    var best: [Int] = []
    var candidate: [Int] = []
    for transposed in [false, true] {
        for rowOrder in linePermutations {
            for columnOrder in linePermutations {
                candidate.removeAll(keepingCapacity: true)
                var labels = [Int](repeating: 0, count: size + 1)
                var nextLabel = 1
                for row in rowOrder {
                    for column in columnOrder {
                        let value = transposed ? grid.cells[column * size + row] : grid.cells[row * size + column]
                        if value != Grid.emptyCell && labels[value] == 0 {
                            // 按第一次出现的顺序给数字重新编号
                            labels[value] = nextLabel
                            nextLabel += 1
                        }
                        candidate.append(labels[value])
                    }
                }
                if best.isEmpty || candidate.lexicographicallyPrecedes(best) { best = candidate }
            }
        }
    }
    return PuzzleFingerprint(value: "s\(size)-" + best.map(String.init).joined())
}
