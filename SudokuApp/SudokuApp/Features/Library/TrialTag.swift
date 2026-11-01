import SudokuEngine
import SwiftUI

/// 「需试错」标签的文案。
enum TrialTagCopy {
    static let text = "需试错"
    static let accessibilityLabel = "需试错：这道题需要假设才能解出"

    /// 难度选择器的副标题。
    /// 产品决策：专家档就是需要试错的题；
    /// 单题标签仍然只看 hardestTechnique，不受这里影响。
    static func pickerSubtitle(for difficulty: Difficulty) -> String? {
        if difficulty == .expert {
            return text
        }
        return nil
    }
}

/// 判断规则：只看评级出的最难技巧，不看难度档、seRating 或分数。
enum TrialTagRule {
    /// 评级成功且最难技巧是试数才算需要试错；评级失败一律不显示标签。
    static func needsTrial(_ result: Result<GradeResult, GradeError>) -> Bool {
        switch result {
        case .success(let grade):
            return grade.hardestTechnique == .trialAndError
        case .failure:
            return false
        }
    }

    /// 真实评级：题库条目都是 9×9，构造不出棋盘就当作不需要试错。
    static func grade(_ entry: PuzzleBankEntry) -> Bool {
        let rules = SudokuEngine.Rules.nineByNine
        guard let grid = try? SudokuEngine.Grid(size: rules.size, cells: entry.givens) else {
            return false
        }
        return needsTrial(DifficultyGrader.grade(grid, rules: rules))
    }
}

/// 按题目指纹缓存评级结果。评级很慢，所以放在后台算，每题只算一次。
actor TrialTagCache {
    typealias Grader = @Sendable (PuzzleBankEntry) -> Bool

    static let shared = TrialTagCache()

    private let grader: Grader
    private var results: [PuzzleFingerprint: Bool] = [:]
    // 同一题同时被问多次时共用一个任务，避免重复评级（actor 会在 await 处重入）
    private var running: [PuzzleFingerprint: Task<Bool, Never>] = [:]

    init(grader: @escaping Grader = { TrialTagRule.grade($0) }) {
        self.grader = grader
    }

    /// 这道题是否需要试错；第一次会在后台线程评级，之后直接读缓存。
    func needsTrial(for entry: PuzzleBankEntry) async -> Bool {
        if let cached = results[entry.id] {
            return cached
        }
        if let task = running[entry.id] {
            return await task.value
        }
        let gradeEntry = grader
        // detached 让评级不占用 actor 和主线程
        let task = Task.detached { gradeEntry(entry) }
        running[entry.id] = task
        let value = await task.value
        results[entry.id] = value
        running[entry.id] = nil
        return value
    }
}

/// 题目行和棋盘页用的小胶囊标签。
struct TrialTagView: View {
    var body: some View {
        Text(TrialTagCopy.text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15), in: Capsule())
            .accessibilityLabel(TrialTagCopy.accessibilityLabel)
    }
}
