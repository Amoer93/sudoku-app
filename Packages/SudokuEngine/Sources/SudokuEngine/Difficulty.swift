/// 难度等级。阈值见 `difficulty(forSERating:)` 和 `docs/Difficulty.md`。
public enum Difficulty: Int, Codable, CaseIterable, Comparable, Sendable {
    case easy, medium, hard, expert

    public static func < (left: Difficulty, right: Difficulty) -> Bool {
        left.rawValue < right.rawValue
    }

    /// 根据 Sudoku Explainer 风格评分返回难度。
    ///
    /// - 2.3 及以下为 easy；2.4 到 3.4（含）为 medium；
    /// - 3.5 到 4.4（含）为 hard；4.5 及以上为 expert。
    public static func difficulty(forSERating rating: Double) -> Difficulty {
        if rating <= 2.3 { return .easy }
        if rating <= 3.4 { return .medium }
        if rating <= 4.4 { return .hard }
        return .expert
    }
}

/// 人工解题技巧。
public enum Technique: Int, Codable, CaseIterable, Comparable, Sendable {
    case nakedSingle, hiddenSingle, nakedPair, hiddenPair, pointing,
         boxLineReduction, nakedTriple, hiddenTriple, nakedQuad,
         hiddenQuad, xWing, swordfish, xyWing, simpleColoring, trialAndError

    public static func < (left: Technique, right: Technique) -> Bool {
        left.rawValue < right.rawValue
    }

    /// 该技巧所属的难度等级，由 SE 值映射得到。
    public var difficulty: Difficulty {
        Difficulty.difficulty(forSERating: seValue)
    }

    /// 每使用一次该技巧对总分的加权贡献。
    public var weight: Int {
        Int((seValue * 10).rounded())
    }
}

/// 评级结果。
public struct GradeResult: Codable, Equatable, Sendable {
    /// 难度档位。用到试数时一律为 expert，否则由 `seRating` 映射。
    public let difficulty: Difficulty
    /// 全过程加权总和（每步 SE 值 × 10），只用于同档内排序。
    public let score: Int
    /// 实际用到的技巧中最高的 SE 值。
    public let seRating: Double
    /// SE 值最高的那个技巧。
    public let hardestTechnique: Technique
    /// 每种技巧被使用的步数。
    public let techniqueCounts: [Technique: Int]

    public init(
        difficulty: Difficulty,
        score: Int,
        seRating: Double,
        hardestTechnique: Technique,
        techniqueCounts: [Technique: Int]
    ) {
        self.difficulty = difficulty
        self.score = score
        self.seRating = seRating
        self.hardestTechnique = hardestTechnique
        self.techniqueCounts = techniqueCounts
    }
}

/// 评级错误。
public enum GradeError: Error, Equatable, Sendable {
    /// 无解。
    case noSolution
    /// 解不唯一。
    case multipleSolutions
}
