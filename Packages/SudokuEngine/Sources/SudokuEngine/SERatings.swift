/// SE（Sudoku Explainer）难度基准值表，全包只在这里维护。
///
/// 数值来源：SukakuExplainer（Sudoku Explainer 的分支）各 Rule/Hint 类里的难度常数，
/// 这里只引用数字，没有复制任何代码（其代码为 LGPL）。
/// `simpleColoring`（单数字染色）取 SE 链类技巧的起点 6.5，仍归专家档；
/// `trialAndError` 不是 SE 技巧，取 11.0，表示超出技巧库、需要试数。
/// 隐性唯一在宫内为 1.2、在行列为 1.5；枚举值只有一个，这里返回 1.5，宫内的 1.2 由评级器单独使用。
/// 完整说明见 `docs/Difficulty.md`。
extension Technique {
    /// 宫内隐性唯一的 SE 值。
    static let hiddenSingleInBoxSEValue = 1.2

    /// 该技巧的 SE 基准值。
    public var seValue: Double {
        switch self {
        case .hiddenSingle: return 1.5
        case .nakedSingle: return 2.3
        case .pointing: return 2.6
        case .boxLineReduction: return 2.8
        case .nakedPair: return 3.0
        case .xWing: return 3.2
        case .hiddenPair: return 3.4
        case .nakedTriple: return 3.6
        case .swordfish: return 3.8
        case .hiddenTriple: return 4.0
        case .xyWing: return 4.2
        case .nakedQuad: return 5.0
        case .hiddenQuad: return 5.4
        case .simpleColoring: return 6.5
        case .trialAndError: return 11.0
        }
    }
}
