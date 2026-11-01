import SudokuEngine

/// App 侧的薄接口，只用引擎的公开 API，方便测试时替换。
protocol PuzzleBankProviding {
    /// 按难度、来源筛选并排序。
    func entries(difficulty: Difficulty?, source: PuzzleSource?, sort: PuzzleSort) -> [PuzzleBankEntry]
    /// 随机抽一题；没有符合条件的就返回 nil。
    func randomEntry<G: RandomNumberGenerator>(
        difficulty: Difficulty?, source: PuzzleSource?, using generator: inout G
    ) -> PuzzleBankEntry?
}

extension PuzzleBank: PuzzleBankProviding {}
