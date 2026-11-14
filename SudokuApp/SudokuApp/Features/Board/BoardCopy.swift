/// 棋盘相关文案。集中放在这里，测试可以直接断言，不用把界面跑起来。
enum BoardCopy {
    static let selectCell = "先点一个格子，再用下面的数字填进去。"
    static let givenLocked = "这是题目里的数字，不能改哦。"
    static let enterDigit = "选一个数字填进去，或者把这格清掉。"
    static let solving = "正在算出答案…"
    static let solved = "答案已经填好了。"
    static let playerCompleted = "太棒了，这道题做完啦！"
    static let autoSolved = "答案已经填好啦。想算做完，可以点「清空」再自己做一遍！"
    static let unsolvable = "这样填下去做不出来了，试试退回几步。"
    static let cleared = "你填的数字已经清掉了。"
    static let checkingSolutions = "正在看看这道题有几个答案…"
    static let noSolution = "现在这样填，做不出来。"
    static let uniqueSolution = "现在这样填，只有一个答案。"
    static let multipleSolutions = "现在这样填，有好几种答案。「全解」只会填其中一种。"
    static let undo = "撤销"
    static let redo = "重做"
    static let clearAll = "清空"
    static let clearCell = "清除"
    static let autoSolve = "全解"
    static let undoHint = "回到上一步"
    static let redoHint = "恢复刚才撤销的填写"
    static let clearAllHint = "清除你填的数字，题目保留"
    static let hint = "提示"
    static let hintHint = "高亮一个现在就能确定的格子，不会填数字"
    static let noHint = "现在还不能确定，可以点「试一试」。"
    static let hintBlockedByConflicts = "有的格子数字撞在一起了，先改一改吧。"
    static let noCandidates = "这一格没数可填了，可能前面填错了，试试退回一步。"
    static let hinted = "提示：亮起来的这一格，现在就能确定填什么。"
    static let clearCellHint = "清除选中的格子"
    static let autoFilter = "灰掉不能填的"
    static let autoFilterHint = "打开后，同一行、同一列、同一个小方块里已经有的数字会变灰，不能点。"
    static let highlightPeers = "点亮相关格子"
    static let highlightPeersHint = "打开后，和选中格子同一行、同一列、同一个小方块的格子会深一点。"
    static let invalidSize = "棋盘尺寸无效"
    static let showCandidates = "显示能填的数"
    static let showCandidatesHint = "打开后，空格里会用小数字显示还能填的数"
    static let startLayer = "试一试"
    static let startLayerHint = "开始试试。这之后填的数字，会换成新的颜色。"
    static let rollbackLayer = "不试了"
    static let rollbackLayerHint = "取消这次试试，这次填的数字都会清掉。"
}

extension BoardCopy {
    /// 无唯一解时的假设提示，例如「现在还不能确定，可以点「试一试」。可以试试：2、5」。
    static func assumption(_ candidates: [Int]) -> String {
        let digits = candidates.map { String($0) }.joined(separator: "、")
        return noHint + "可以试试：" + digits
    }

    /// 当前蒙版层数的说明文字。0 层返回空串，界面在 0 层不显示这行字。
    static func layerStatus(_ depth: Int) -> String {
        if depth == 0 {
            return ""
        }
        if depth == 1 {
            return "正在试试。"
        }
        return "正在试试，第 \(depth) 层。"
    }
}

/// 操作反馈。空闲时由界面另外显示选题提示。
enum BoardNotice: Equatable {
    case idle
    case givenLocked
    case solved
    case autoSolved
    case playerCompleted
    case unsolvable
    case cleared
    case hinted
    case noHint
    case assumption([Int])
    case hintBlockedByConflicts

    var text: String? {
        switch self {
        case .idle:
            return nil
        case .givenLocked:
            return BoardCopy.givenLocked
        case .solved:
            return BoardCopy.solved
        case .autoSolved:
            return BoardCopy.autoSolved
        case .playerCompleted:
            return BoardCopy.playerCompleted
        case .unsolvable:
            return BoardCopy.unsolvable
        case .cleared:
            return BoardCopy.cleared
        case .hinted:
            return BoardCopy.hinted
        case .noHint:
            return BoardCopy.noHint
        case let .assumption(candidates):
            return BoardCopy.assumption(candidates)
        case .hintBlockedByConflicts:
            return BoardCopy.hintBlockedByConflicts
        }
    }

    var isWarning: Bool {
        switch self {
        case .givenLocked, .unsolvable, .hintBlockedByConflicts:
            return true
        case .idle, .solved, .autoSolved, .playerCompleted, .cleared, .hinted, .noHint, .assumption:
            return false
        }
    }
}
