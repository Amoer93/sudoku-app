/// 棋盘相关文案。集中放在这里，测试可以直接断言，不用把界面跑起来。
enum BoardCopy {
    static let selectCell = "先点一个格子，再用下方数字键输入。"
    static let givenLocked = "这是题目给定的数字，不能改。"
    static let enterDigit = "选择数字填入，或清除这一格。"
    static let solving = "正在求解…"
    static let solved = "已填入示例解。"
    static let unsolvable = "按当前填法，示例数据里没有解。"
    static let cleared = "已清除你填入的数字。"
    static let checkingSolutions = "正在查看这道题有几个解…"
    static let noSolution = "示例数据里没有解。"
    static let uniqueSolution = "示例数据：唯一解。"
    static let multipleSolutions = "示例数据：有多个解。"
    static let undo = "撤销"
    static let redo = "重做"
    static let clearAll = "清空"
    static let clearCell = "清除"
    static let autoSolve = "自动解题"
    static let undoHint = "回到上一步"
    static let redoHint = "恢复刚才撤销的填写"
    static let clearAllHint = "清除你填的数字，题目保留"
    static let clearCellHint = "清除选中的格子"
    static let invalidSize = "棋盘尺寸无效"
}

/// 操作反馈。空闲时由界面另外显示选题提示。
enum BoardNotice: Equatable {
    case idle
    case givenLocked
    case solved
    case unsolvable
    case cleared

    var text: String? {
        switch self {
        case .idle:
            return nil
        case .givenLocked:
            return BoardCopy.givenLocked
        case .solved:
            return BoardCopy.solved
        case .unsolvable:
            return BoardCopy.unsolvable
        case .cleared:
            return BoardCopy.cleared
        }
    }

    var isWarning: Bool {
        switch self {
        case .givenLocked, .unsolvable:
            return true
        case .idle, .solved, .cleared:
            return false
        }
    }
}
