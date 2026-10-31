/// 难度评级入口。
public enum DifficultyGrader {
    /// 对标准 9×9 数独进行基于技巧的评级。
    ///
    /// 前置条件：`rules == .nineByNine` 且 `grid.size == 9`；传入其他尺寸会触发 precondition 直接崩溃，
    /// 调用方（如导入入库）须先判断尺寸。
    ///
    /// 已经填满且正确的盘面不需要任何技巧：返回简单档、`seRating` 为 0、`score` 为 0、
    /// `techniqueCounts` 为空；`hardestTechnique` 此时只是占位值 `.nakedSingle`。
    public static func grade(_ grid: Grid, rules: Rules) -> Result<GradeResult, GradeError> {
        precondition(rules == .nineByNine, "only nineByNine is supported")
        precondition(grid.size == 9, "only 9x9 grids are supported")

        switch makeGradingBoard(grid: grid) {
        case .failure(let error):
            return .failure(error)
        case .success(let board):
            if board.isSolved {
                // 已解盘面：无需技巧，seRating 0，hardestTechnique 仅为占位
                return .success(GradeResult(
                    difficulty: .easy, score: 0, seRating: 0,
                    hardestTechnique: .nakedSingle, techniqueCounts: [:]
                ))
            }
            return gradeSolving(board: board)
        }
    }
}

private func makeGradingBoard(grid: Grid) -> Result<GradingBoard, GradeError> {
    let count = solutionCount(grid, rules: .nineByNine, limit: 2)
    if count == 0 { return .failure(.noSolution) }
    if count >= 2 { return .failure(.multipleSolutions) }
    guard let solution = solve(grid, rules: .nineByNine) else {
        return .failure(.noSolution)
    }
    guard let board = GradingBoard(grid: grid, solution: solution) else {
        return .failure(.noSolution)
    }
    return .success(board)
}

private func gradeSolving(board: GradingBoard) -> Result<GradeResult, GradeError> {
    var board = board
    var counts: [Technique: Int] = [:]
    var score = 0
    var seRating = 0.0
    var hardestTechnique = Technique.nakedSingle
    let steps = gradingSteps()

    while !board.isSolved {
        if let step = steps.first(where: { $0.apply(&board) }) {
            record(step.technique, stepSE: step.seValue)
        } else if board.applyTrialAndError() {
            record(.trialAndError)
        }
    }

    let difficulty = counts[.trialAndError, default: 0] > 0
        ? .expert
        : Difficulty.difficulty(forSERating: seRating)
    return .success(GradeResult(
        difficulty: difficulty, score: score, seRating: seRating,
        hardestTechnique: hardestTechnique, techniqueCounts: counts
    ))

    func record(_ technique: Technique, stepSE: Double? = nil) {
        counts[technique, default: 0] += 1
        let value = stepSE ?? technique.seValue
        score += Int((value * 10).rounded())
        if value > seRating {
            seRating = value
            hardestTechnique = technique
        }
    }
}

private struct GradingStep {
    let technique: Technique
    let seValue: Double
    let apply: (inout GradingBoard) -> Bool

    init(_ technique: Technique, seValue: Double? = nil, apply: @escaping (inout GradingBoard) -> Bool) {
        self.technique = technique
        self.seValue = seValue ?? technique.seValue
        self.apply = apply
    }
}

private func gradingSteps() -> [GradingStep] {
    [
        GradingStep(.hiddenSingle, seValue: Technique.hiddenSingleInBoxSEValue) {
            $0.applyHiddenSingle(boxesOnly: true)
        },
        GradingStep(.hiddenSingle) { $0.applyHiddenSingle(boxesOnly: false) },
        GradingStep(.nakedSingle) { $0.applyNakedSingle() },
        GradingStep(.pointing) { $0.applyPointing() },
        GradingStep(.boxLineReduction) { $0.applyBoxLineReduction() },
        GradingStep(.nakedPair) { $0.applyNakedSubset(size: 2) },
        GradingStep(.xWing) { $0.applyXWing() },
        GradingStep(.hiddenPair) { $0.applyHiddenSubset(size: 2) },
        GradingStep(.nakedTriple) { $0.applyNakedSubset(size: 3) },
        GradingStep(.swordfish) { $0.applySwordfish() },
        GradingStep(.hiddenTriple) { $0.applyHiddenSubset(size: 3) },
        GradingStep(.xyWing) { $0.applyXYWing() },
        GradingStep(.nakedQuad) { $0.applyNakedSubset(size: 4) },
        GradingStep(.hiddenQuad) { $0.applyHiddenSubset(size: 4) },
        GradingStep(.chain) { $0.applyChain() },
    ]
}
