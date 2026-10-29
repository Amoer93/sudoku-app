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

    var detail: String {
        switch self {
        case .four:
            return "2×2 宫"
        case .five:
            return "拉丁方，无宫"
        case .nine:
            return "3×3 宫"
        }
    }

    var rules: Rules {
        switch self {
        case .four:
            return Rules(size: 4, boxRows: 2, boxCols: 2)
        case .five:
            return Rules(size: 5, boxRows: nil, boxCols: nil)
        case .nine:
            return Rules(size: 9, boxRows: 3, boxCols: 3)
        }
    }
}
