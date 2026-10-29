/// 线的种类。外框和宫线分开：5×5 有外框，但没有宫线。
enum BoardLineWeight: Equatable {
    case hairline
    case frame
    case box

    /// 线宽（点）。宫线最粗，用来和普通格线区分。
    var points: Double {
        switch self {
        case .hairline:
            return 1
        case .frame:
            return 2
        case .box:
            return 3.5
        }
    }
}

/// 按规则决定每一条线的粗细。竖线看宫的列数，横线看宫的行数。
enum BoardLines {
    static func verticalWeight(line: Int, rules: Rules) -> BoardLineWeight {
        let span = rules.hasBoxes ? rules.boxCols : nil
        return weight(line: line, size: rules.size, span: span)
    }

    static func horizontalWeight(line: Int, rules: Rules) -> BoardLineWeight {
        let span = rules.hasBoxes ? rules.boxRows : nil
        return weight(line: line, size: rules.size, span: span)
    }

    /// line 从 0 到 size。两端是外框，中间能被 span 整除的才是宫线。
    /// span 直接传入，方便测 2 和 3 这种不同的宫宽，不必构造引擎不接受的规则。
    static func weight(line: Int, size: Int, span: Int?) -> BoardLineWeight {
        guard size > 0, line >= 0, line <= size else {
            return .hairline
        }
        if line == 0 || line == size {
            return .frame
        }
        guard let span, span > 0, line.isMultiple(of: span) else {
            return .hairline
        }
        return .box
    }
}
