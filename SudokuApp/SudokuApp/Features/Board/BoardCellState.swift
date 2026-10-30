/// 一个格子要画出来所需的状态。冲突标记来自引擎，不在这里计算。
struct BoardCellState: Equatable, Identifiable, Sendable {
    let index: Int
    let row: Int
    let column: Int
    let value: Int
    let isGiven: Bool
    let isSelected: Bool
    let isConflict: Bool
    /// 提示高亮的格子。
    var isHinted = false
    /// 数字所属的假设层，0 表示确定数字。
    var layerDepth = 0

    var id: Int {
        index
    }

    var accessibilityLabel: String {
        let position = "第 \(row + 1) 行第 \(column + 1) 列"
        let content = value == 0 ? "空" : "数字 \(value)"
        let notes = statusNotes
        if notes.isEmpty {
            return "\(position)，\(content)"
        }
        let detail = notes.joined(separator: "，")
        return "\(position)，\(content)，\(detail)"
    }

    private var statusNotes: [String] {
        var notes: [String] = []
        if isGiven {
            notes.append("题目给定")
        }
        if isConflict {
            notes.append("冲突")
        }
        if isHinted {
            notes.append("提示格")
        }
        if isSelected {
            notes.append("已选中")
        }
        return notes
    }
}
