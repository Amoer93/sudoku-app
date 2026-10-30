/// 棋盘相关文案。集中放在这里，测试可以直接断言，不用把界面跑起来。
enum BoardCopy {
    static let selectCell = "先点一个格子，再用下方数字键输入。"
    static let givenLocked = "这是题目给定的数字，不能改。"
    static let enterDigit = "选择数字填入，或清除这一格。"
    static let solving = "正在求解…"
    static let solved = "已填入解。"
    static let unsolvable = "按当前填法没有解，试试撤销几步。"
    static let cleared = "已清除你填入的数字。"
    static let checkingSolutions = "正在查看这道题有几个解…"
    static let noSolution = "当前盘面没有解。"
    static let uniqueSolution = "当前盘面有唯一解。"
    static let multipleSolutions = "当前盘面有多个解，自动解题只填入其中一个。"
    static let undo = "撤销"
    static let redo = "重做"
    static let clearAll = "清空"
    static let clearCell = "清除"
    static let autoSolve = "自动解题"
    static let undoHint = "回到上一步"
    static let redoHint = "恢复刚才撤销的填写"
    static let clearAllHint = "清除你填的数字，题目保留"
    static let hint = "提示"
    static let hintHint = "高亮一个现在就能确定的格子，不会填数字"
    static let noHint = "当前无唯一解，请假设。"
    static let hintBlockedByConflicts = "盘面有冲突，请先修正。"
    static let noCandidates = "这一格没有能填的数字，可能前面填错了，试试撤销。"
    static let hinted = "提示：高亮的这一格现在就能确定。"
    static let clearCellHint = "清除选中的格子"
    static let autoFilter = "自动筛选"
    static let autoFilterHint = "打开后，同行、同列、同宫已有的数字会变灰，不能点"
    static let invalidSize = "棋盘尺寸无效"
}

/// 操作反馈。空闲时由界面另外显示选题提示。
enum BoardNotice: Equatable {
    case idle
    case givenLocked
    case solved
    case unsolvable
    case cleared
    case hinted
    case noHint
    case hintBlockedByConflicts

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
        case .hinted:
            return BoardCopy.hinted
        case .noHint:
            return BoardCopy.noHint
        case .hintBlockedByConflicts:
            return BoardCopy.hintBlockedByConflicts
        }
    }

    var isWarning: Bool {
        switch self {
        case .givenLocked, .unsolvable, .hintBlockedByConflicts:
            return true
        case .idle, .solved, .cleared, .hinted, .noHint:
            return false
        }
    }
}
