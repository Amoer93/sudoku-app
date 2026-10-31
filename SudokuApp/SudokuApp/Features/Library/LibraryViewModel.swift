import Foundation
import Observation
import SudokuEngine

/// 题库页的状态：筛选、排序，以及把题库条目变成可玩的题。
@MainActor
@Observable
final class LibraryViewModel {
    var bank: any PuzzleBankProviding
    var difficultyFilter: Difficulty?
    var sourceFilter: PuzzleSource?
    var sort: PuzzleSort = .sourceThenDifficulty
    init(bank: any PuzzleBankProviding) { self.bank = bank }

    var visibleEntries: [PuzzleBankEntry] {
        bank.entries(difficulty: difficultyFilter, source: sourceFilter, sort: sort)
    }

    /// 换成新读出的题库（比如刚导入了题）。
    func reload(_ newBank: PuzzleBank) {
        bank = newBank
    }

    /// 整个题库是不是空的（不受筛选影响）。
    var isBankEmpty: Bool {
        bank.entries(difficulty: nil, source: nil, sort: .sourceThenDifficulty).isEmpty
    }

    /// 某个难度下有没有题。
    func hasEntries(difficulty: Difficulty) -> Bool {
        !bank.entries(difficulty: difficulty, source: nil, sort: .sourceThenDifficulty).isEmpty
    }

    /// 清掉所有筛选条件。
    func clearFilters() {
        difficultyFilter = nil
        sourceFilter = nil
    }

    /// 从指定难度里随机抽一题；没有就返回 nil，调用方退回内置题。
    func newGamePuzzle(difficulty: Difficulty) -> SamplePuzzle? {
        var generator = SystemRandomNumberGenerator()
        return newGamePuzzle(difficulty: difficulty, using: &generator)
    }

    /// 测试用：传入固定随机数，结果可复现。
    func newGamePuzzle<G: RandomNumberGenerator>(difficulty: Difficulty, using generator: inout G) -> SamplePuzzle? {
        let entry = bank.randomEntry(difficulty: difficulty, source: nil, using: &generator)
        return entry.map { puzzle(for: $0) }
    }

    /// 题库条目转成棋盘题（同步，会求解）。界面请用 `resolvePuzzle(for:)`，别在主线程调。
    func puzzle(for entry: PuzzleBankEntry) -> SamplePuzzle {
        Self.makePuzzle(from: entry)
    }

    /// 在后台线程求解，点击时调用，不卡界面。
    nonisolated static func resolvePuzzle(for entry: PuzzleBankEntry) async -> SamplePuzzle {
        await Task.detached { makePuzzle(from: entry) }.value
    }

    /// 正在求解的那一行；nil 表示没有在打开。
    private(set) var openingEntryID: PuzzleFingerprint?

    /// 是否正在打开某一题（用来显示转圈、忽略重复点击）。
    var isOpening: Bool { openingEntryID != nil }

    /// 点击一行：求解期间 isOpening 为 true，结束后复位；正在打开时直接返回 nil。
    func openPuzzle(for entry: PuzzleBankEntry) async -> SamplePuzzle? {
        guard !isOpening else {
            return nil
        }
        openingEntryID = entry.id
        defer { openingEntryID = nil }
        return await Self.resolvePuzzle(for: entry)
    }

    /// 随机抽题（很快），再在后台求解；抽不到返回 nil。
    func newGamePuzzleAsync(difficulty: Difficulty) async -> SamplePuzzle? {
        var generator = SystemRandomNumberGenerator()
        guard let entry = bank.randomEntry(difficulty: difficulty, source: nil, using: &generator) else {
            return nil
        }
        return await Self.resolvePuzzle(for: entry)
    }

    /// 纯计算，不碰界面状态，所以能放在后台线程跑。求不出解就用题面当答案。
    nonisolated static func makePuzzle(from entry: PuzzleBankEntry) -> SamplePuzzle {
        let rules = Rules.nineByNine
        let givens = (try? Grid(size: rules.size, cells: entry.givens)) ?? Grid(rules: rules)
        let solution = EngineBoardAdapter().solve(givens, rules: rules) ?? givens
        return SamplePuzzle(rules: rules, givens: givens, solution: solution)
    }
}

/// 一次“开始游戏”的导航请求。每次点击生成新 id，所以同一题也能再次进入。
struct PlayRoute: Identifiable, Hashable {
    let id = UUID()
    let preset: BoardPreset
    let puzzle: SamplePuzzle?

    static func == (lhs: PlayRoute, rhs: PlayRoute) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
