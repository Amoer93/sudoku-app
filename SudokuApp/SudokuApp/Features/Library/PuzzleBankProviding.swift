import SudokuEngine

/// App 侧的薄接口，只用引擎的公开 API，方便测试时替换。
protocol PuzzleBankProviding {
    /// 按难度、来源筛选并排序。
    func entries(difficulty: Difficulty?, source: PuzzleSource?, sort: PuzzleSort) -> [PuzzleBankEntry]
    /// 随机抽一题；没有符合条件的就返回 nil。
    func randomEntry<G: RandomNumberGenerator>(
        difficulty: Difficulty?, source: PuzzleSource?, using generator: inout G
    ) -> PuzzleBankEntry?
    /// 只取某个边长的题，其余同上。
    func entries(size: Int, difficulty: Difficulty?, source: PuzzleSource?, sort: PuzzleSort) -> [PuzzleBankEntry]
    /// 在某个边长的题里随机抽一题。
    func randomEntry<G: RandomNumberGenerator>(
        size: Int, difficulty: Difficulty?, source: PuzzleSource?, using generator: inout G
    ) -> PuzzleBankEntry?
}

/// 默认实现：先按旧方法取，再按边长筛。测试替身不用自己写；真正的 PuzzleBank 用引擎自带的。
extension PuzzleBankProviding {
    func entries(size: Int, difficulty: Difficulty?, source: PuzzleSource?, sort: PuzzleSort) -> [PuzzleBankEntry] {
        entries(difficulty: difficulty, source: source, sort: sort).filter { $0.size == size }
    }

    func randomEntry<G: RandomNumberGenerator>(
        size: Int, difficulty: Difficulty?, source: PuzzleSource?, using generator: inout G
    ) -> PuzzleBankEntry? {
        let candidates = entries(size: size, difficulty: difficulty, source: source, sort: .difficultyAscending)
        return candidates.randomElement(using: &generator)
    }
}

extension PuzzleBank: PuzzleBankProviding {}

extension PuzzleBank {
    /// 加上 4×4 / 5×5 的内置题，只给首页用（题库页不合并）。读不出来或没有题就原样返回。
    func mergingSmallBuiltin() -> PuzzleBank {
        guard let small = try? PuzzleBank.loadSmallBuiltin(), !small.isEmpty else {
            return self
        }
        return PuzzleBank(entries: entries + small)
    }
}
