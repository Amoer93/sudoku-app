import Foundation

// 镜像 SudokuEngine 的接口，引擎发布后删掉改用引擎类型
/// 题目难度，名字和引擎一致。
enum Difficulty: String, CaseIterable, Hashable, Sendable, Codable {
    case easy, medium, hard, expert
    /// 排序用的序号，按声明顺序从易到难。
    fileprivate var rank: Int { Difficulty.allCases.firstIndex(of: self) ?? 0 }
}

/// 题目来源。
enum PuzzleSource: String, CaseIterable, Hashable, Sendable, Codable { case builtin, userUpload }
/// 题目指纹，用来判重。
struct PuzzleFingerprint: Hashable, Sendable, Codable { let value: String }

/// 题库里的一条题。`givens` 按行排列，0 表示空格。
struct PuzzleBankEntry: Identifiable, Hashable, Sendable {
    let id: PuzzleFingerprint
    let size: Int
    let givens: [Int]
    let difficulty: Difficulty
    let score: Int
    let source: PuzzleSource
    let addedAt: Date
}

/// 入库失败的原因。
enum BankError: Error, Equatable {
    case duplicate(existing: PuzzleBankEntry)
    case ungradable, unsupportedSize
}

/// 题库排序方式。
enum PuzzleBankSort: CaseIterable, Sendable {
    case difficultyAscending, difficultyDescending, addedAtNewest, addedAtOldest, sourceThenDifficulty
}

/// App 侧的题库接口，存盘留到导入 PR。
protocol PuzzleBankProviding {
    func entries(difficulty: Difficulty?, source: PuzzleSource?, sort: PuzzleBankSort) -> [PuzzleBankEntry]
    func randomEntry<G: RandomNumberGenerator>(
        difficulty: Difficulty?, source: PuzzleSource?, using generator: inout G
    ) -> PuzzleBankEntry?
    mutating func add(_ grid: Grid, rules: Rules, source: PuzzleSource) -> Result<PuzzleBankEntry, BankError>
}

extension PuzzleBankProviding {
    /// 不传条件就是全部，默认「内置优先」排序。
    func entries(difficulty: Difficulty? = nil, source: PuzzleSource? = nil) -> [PuzzleBankEntry] {
        entries(difficulty: difficulty, source: source, sort: .sourceThenDifficulty)
    }
    func randomEntry(difficulty: Difficulty?, source: PuzzleSource?) -> PuzzleBankEntry? {
        var generator = SystemRandomNumberGenerator()
        return randomEntry(difficulty: difficulty, source: source, using: &generator)
    }
}

/// 占位题库，用内存数组。真题库接入后删除。
struct MockPuzzleBank: PuzzleBankProviding {
    private(set) var storedEntries: [PuzzleBankEntry]
    private let clock: () -> Date

    init(entries: [PuzzleBankEntry], clock: @escaping () -> Date = { Date() }) {
        storedEntries = entries
        self.clock = clock
    }

    /// 每个难度一题，题面都借用示例 9×9。
    static func builtin(now: Date) -> MockPuzzleBank {
        let givens = FixtureLibrary.puzzle(for: .nine).givens.cells
        let result = Difficulty.allCases.map { difficulty in
            PuzzleBankEntry(
                id: PuzzleFingerprint(value: "builtin-\(difficulty.rawValue)"), size: 9, givens: givens,
                difficulty: difficulty, score: (difficulty.rank + 1) * 20, source: .builtin, addedAt: now
            )
        }
        return MockPuzzleBank(entries: result)
    }

    func entries(difficulty: Difficulty?, source: PuzzleSource?, sort: PuzzleBankSort) -> [PuzzleBankEntry] {
        let matches = storedEntries.filter { entry in
            (difficulty == nil || entry.difficulty == difficulty) && (source == nil || entry.source == source)
        }
        return matches.sorted { Self.precedes($0, $1, sort: sort) }
    }

    func randomEntry<G: RandomNumberGenerator>(
        difficulty: Difficulty?, source: PuzzleSource?, using generator: inout G
    ) -> PuzzleBankEntry? {
        entries(difficulty: difficulty, source: source, sort: .addedAtOldest).randomElement(using: &generator)
    }

    mutating func add(_ grid: Grid, rules: Rules, source: PuzzleSource) -> Result<PuzzleBankEntry, BankError> {
        guard rules.size == 9 else { return .failure(.unsupportedSize) }
        if let existing = storedEntries.first(where: { $0.givens == grid.cells }) {
            return .failure(.duplicate(existing: existing))
        }
        let key = grid.cells.map(String.init).joined()
        // 占位：真引擎会给出真实难度和分数
        let entry = PuzzleBankEntry(
            id: PuzzleFingerprint(value: "user-\(key)"), size: rules.size, givens: grid.cells,
            difficulty: .medium, score: 50, source: source, addedAt: clock()
        )
        storedEntries.append(entry)
        return .success(entry)
    }

    /// 主排序键相同时按 id 排，保证结果稳定。
    private static func precedes(_ left: PuzzleBankEntry, _ right: PuzzleBankEntry, sort: PuzzleBankSort) -> Bool {
        primaryOrder(left, right, sort: sort) ?? (left.id.value < right.id.value)
    }

    /// 只看主排序键：分得出先后返回结果，打平返回 nil。
    private static func primaryOrder(_ left: PuzzleBankEntry, _ right: PuzzleBankEntry, sort: PuzzleBankSort) -> Bool? {
        switch sort {
        case .difficultyAscending: return order(left.difficulty.rank, right.difficulty.rank)
        case .difficultyDescending: return order(right.difficulty.rank, left.difficulty.rank)
        case .addedAtNewest: return order(right.addedAt, left.addedAt)
        case .addedAtOldest: return order(left.addedAt, right.addedAt)
        case .sourceThenDifficulty:
            if left.source != right.source { return left.source == .builtin }
            return order(left.difficulty.rank, right.difficulty.rank)
        }
    }

    /// 相等返回 nil，表示这一级没分出胜负。
    private static func order<Key: Comparable>(_ first: Key, _ second: Key) -> Bool? {
        if first == second { return nil }
        return first < second
    }
}
