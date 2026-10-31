/// 题库界面的中文文案。
enum LibraryCopy {
    static let entry = "题库"
    static let all = "全部"
    static let sortMenu = "排序与筛选"
    static let sortTitle = "排序"
    static let difficultyTitle = "难度"
    static let sourceTitle = "来源"
    static let emptyList = "没有符合条件的题目"
    static func title(_ difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        case .expert: return "专家"
        }
    }
    static func title(_ source: PuzzleSource) -> String {
        switch source {
        case .builtin: return "内置"
        case .userUpload: return "用户上传"
        }
    }
    static func title(_ sort: PuzzleBankSort) -> String {
        switch sort {
        case .difficultyAscending: return "难度从易到难"
        case .difficultyDescending: return "难度从难到易"
        case .addedAtNewest: return "最新添加"
        case .addedAtOldest: return "最早添加"
        case .sourceThenDifficulty: return "内置优先"
        }
    }
    static func message(_ error: BankError) -> String {
        switch error {
        case .duplicate: return "这道题已经在题库里"
        case .ungradable: return "无法评定难度"
        case .unsupportedSize: return "该尺寸暂不入库"
        }
    }
}
