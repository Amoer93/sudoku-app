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

    /// 题库条目转成棋盘题；求不出解就用题面当答案。
    func puzzle(for entry: PuzzleBankEntry) -> SamplePuzzle {
        let rules = Rules.nineByNine
        let givens = (try? Grid(size: rules.size, cells: entry.givens)) ?? Grid(rules: rules)
        let solution = EngineBoardAdapter().solve(givens, rules: rules) ?? givens
        return SamplePuzzle(rules: rules, givens: givens, solution: solution)
    }
}
