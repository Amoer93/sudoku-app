import SudokuEngine

/// 首页可选的三种棋盘。更小的入口先不做，避免把规则入口做复杂。
enum BoardPreset: String, CaseIterable, Identifiable {
    case four
    case five
    case nine

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .four:
            return "4×4"
        case .five:
            return "5×5"
        case .nine:
            return "9×9"
        }
    }

    var rules: Rules {
        switch self {
        case .four:
            return .fourByFour
        case .five:
            return .fiveByFive
        case .nine:
            return .nineByNine
        }
    }

    var size: Int { rules.size }

    /// 读屏用的名字，比屏幕上的标题多说一句是哪种棋盘。
    var accessibilityTitle: String {
        if self == .nine {
            return title + " 九宫格"
        }
        return title + " 小棋盘"
    }

    /// 这个尺寸的内置题有哪些难度：小棋盘只有简单和困难。
    var difficulties: [Difficulty] {
        if self == .nine {
            return Difficulty.allCases
        }
        return [.easy, .hard]
    }

    /// 把难度夹到这个尺寸有的档位：没有的档（中等、专家）回到困难。
    func clamping(_ difficulty: Difficulty) -> Difficulty {
        if difficulties.contains(difficulty) {
            return difficulty
        }
        return .hard
    }

    /// 题库条目的边长对应的棋盘；不是 4 或 5 的都当 9×9。
    static func forSize(_ size: Int) -> BoardPreset {
        switch size {
        case 4: return .four
        case 5: return .five
        default: return .nine
        }
    }
}
